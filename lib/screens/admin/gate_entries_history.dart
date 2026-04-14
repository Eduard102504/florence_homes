import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/gate_entry_model.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GateEntriesHistory extends StatefulWidget {
  const GateEntriesHistory({super.key});

  @override
  State<GateEntriesHistory> createState() => _GateEntriesHistoryState();
}

class _GateEntriesHistoryState extends State<GateEntriesHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GateEntryModel> _entries = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  String _selectedResident = 'all';
  String _selectedEntryType = 'all';
  List<GateEntryModel> _filteredEntries = [];
  String _searchQuery = '';
  DateTime? _specificDate;
  TimeOfDay? _specificTime;
  List<String> _residents = [];
  Map<String, String> _residentNames = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _loadEntries();
  }

  Future<void> _loadResidents() async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'resident')
        .get();

    setState(() {
      _residents = ['all'];
      for (var doc in snapshot.docs) {
        String id = doc.id;
        String name = doc.get('fullName');
        _residents.add(id);
        _residentNames[id] = name;
      }
    });
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);

    Query query = _firestore.collection('gate_entries').orderBy('timestamp', descending: true);

    if (_dateRange != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: _dateRange!.start)
          .where('timestamp', isLessThanOrEqualTo: _dateRange!.end);
    }

    if (_selectedResident != 'all') {
      query = query.where('residentId', isEqualTo: _selectedResident);
    }

    if (_selectedEntryType != 'all') {
      query = query.where('entryType', isEqualTo: _selectedEntryType);
    }

    QuerySnapshot snapshot = await query.limit(500).get();

    setState(() {
      _entries = snapshot.docs.map((doc) {
        return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      _applySearchFilter();
      _isLoading = false;
    });
  }

  void _applySearchFilter() {
    List<GateEntryModel> temp = List.from(_entries);

    // Search by resident name or visitor name
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((entry) {
        return entry.residentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (entry.visitorName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Filter by specific date
    if (_specificDate != null) {
      temp = temp.where((entry) {
        return entry.timestamp.year == _specificDate!.year &&
            entry.timestamp.month == _specificDate!.month &&
            entry.timestamp.day == _specificDate!.day;
      }).toList();
    }

    // Filter by specific time
    if (_specificTime != null) {
      temp = temp.where((entry) {
        return entry.timestamp.hour == _specificTime!.hour &&
            entry.timestamp.minute == _specificTime!.minute;
      }).toList();
    }

    setState(() {
      _filteredEntries = temp;
    });
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    String filterTitle = 'All Entries';
    if (_dateRange != null) {
      filterTitle = '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}';
    } else if (_specificDate != null) {
      filterTitle = 'Date: ${DateFormat('MMM dd, yyyy').format(_specificDate!)}';
    } else if (_specificTime != null) {
      filterTitle = 'Time: ${_specificTime!.format(context)}';
    } else if (_searchQuery.isNotEmpty) {
      filterTitle = 'Search: $_searchQuery';
    } else if (_selectedResident != 'all') {
      filterTitle = 'Resident: ${_residentNames[_selectedResident] ?? 'Unknown'}';
    } else if (_selectedEntryType != 'all') {
      filterTitle = 'Type: ${_selectedEntryType.toUpperCase()}';
    }

    // Build table rows
    final List<pw.TableRow> tableRows = [];

    // Header
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Padding(child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Resident', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Visitor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
          pw.Padding(child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
        ],
      ),
    );

    // Data rows - USING _filteredEntries
    for (int i = 0; i < _filteredEntries.length; i++) {
      final entry = _filteredEntries[i];
      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(child: pw.Text(DateFormat('yyyy-MM-dd').format(entry.timestamp), style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(child: pw.Text(DateFormat('hh:mm a').format(entry.timestamp), style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(child: pw.Text(entry.residentName, style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(child: pw.Text(entry.entryType.toUpperCase(), style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(child: pw.Text(entry.visitorName ?? '-', style: const pw.TextStyle(fontSize: 9)), padding: const pw.EdgeInsets.all(6)),
            pw.Padding(
              child: pw.Text(
                entry.status.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: entry.status == 'entry' ? PdfColors.green : PdfColors.red,
                ),
              ),
              padding: const pw.EdgeInsets.all(6),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pw.PageOrientation.portrait,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Florence Homes - Gate Entries Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Generated: ${DateFormat('MMM dd, yyyy hh:mm a').format(now)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.Text('Filter: $filterTitle', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue)),
                  pw.Text('Total Entries: ${_filteredEntries.length}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                ],
              ),
            ),
            pw.Table(border: pw.TableBorder.all(color: PdfColors.grey), children: tableRows),
            pw.SizedBox(height: 20),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(child: pw.Text('Total Entries', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('${_filteredEntries.length}'), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('RFID Scans', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('${_filteredEntries.where((e) => e.entryType == 'rfid').length}'), padding: const pw.EdgeInsets.all(6)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(child: pw.Text('QR Scans', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('${_filteredEntries.where((e) => e.entryType.toLowerCase().contains('qr')).length}'), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('Manual Entries', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text('${_filteredEntries.where((e) => e.entryType == 'manual').length}'), padding: const pw.EdgeInsets.all(6)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('Report generated by Florence Homes Gate System', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey), textAlign: pw.TextAlign.center),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/gate_entries_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Gate Entries Report');
  }

  Future<void> _exportToCSV() async {
    List<List<dynamic>> rows = [
      ['Date', 'Time', 'Resident', 'Type', 'Visitor', 'Status']
    ];

    // USING _filteredEntries (hindi _entries)
    for (var entry in _filteredEntries) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(entry.timestamp),
        DateFormat('HH:mm:ss').format(entry.timestamp),
        entry.residentName,
        entry.entryType.toUpperCase(),
        entry.visitorName ?? '-',
        entry.status.toUpperCase(),
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/gate_entries_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Gate Entries Export');
  }

  @override
  Widget build(BuildContext context) {
    // Use filtered entries for stats and list
    final totalEntries = _filteredEntries.length;
    final rfidEntries = _filteredEntries.where((e) => e.entryType == 'rfid').length;
    final qrEntries = _filteredEntries.where((e) => e.entryType.toLowerCase().contains('qr')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Entries History'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
          ),
        ],
      ),
      body: Column(
        children: [
          // ========== NEW: SEARCH BAR ==========
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by resident or visitor name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                    _applySearchFilter();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applySearchFilter();
              },
            ),
          ),

          // ========== NEW: DATE & TIME FILTER BUTTONS ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDateFilterDialog,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(_specificDate != null
                        ? DateFormat('MMM dd, yyyy').format(_specificDate!)
                        : 'Specific Date'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTimeFilterDialog,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_specificTime != null
                        ? _specificTime!.format(context)
                        : 'Specific Time'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
                if (_specificDate != null || _specificTime != null || _searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ========== EXISTING: ACTIVE FILTERS DISPLAY (Date Range, Resident, Entry Type) ==========
          if (_dateRange != null || _selectedResident != 'all' || _selectedEntryType != 'all')
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, size: 16),
                    const SizedBox(width: 8),
                    if (_dateRange != null)
                      Chip(
                        label: Text(
                          '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                        ),
                        onDeleted: () {
                          setState(() {
                            _dateRange = null;
                          });
                          _loadEntries();
                        },
                      ),
                    if (_selectedResident != 'all')
                      Chip(
                        label: Text('Resident: ${_residentNames[_selectedResident] ?? 'Unknown'}'),
                        onDeleted: () {
                          setState(() {
                            _selectedResident = 'all';
                          });
                          _loadEntries();
                        },
                      ),
                    if (_selectedEntryType != 'all')
                      Chip(
                        label: Text('Type: ${_selectedEntryType.toUpperCase()}'),
                        onDeleted: () {
                          setState(() {
                            _selectedEntryType = 'all';
                          });
                          _loadEntries();
                        },
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _dateRange = null;
                          _selectedResident = 'all';
                          _selectedEntryType = 'all';
                        });
                        _loadEntries();
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
            ),

          // ========== UPDATED STATS (using _filteredEntries) ==========
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Entries',
                    totalEntries.toString(),
                    Icons.door_front_door,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'RFID Scans',
                    rfidEntries.toString(),
                    Icons.nfc,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'QR Scans',
                    qrEntries.toString(),
                    Icons.qr_code,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // ========== UPDATED ENTRIES LIST (using _filteredEntries) ==========
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No entries found'),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEntries.length,
              itemBuilder: (context, index) {
                final entry = _filteredEntries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(entry.entryType),
                      child: Icon(
                        _getTypeIcon(entry.entryType),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(entry.residentName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.entryType.toUpperCase()),
                        if (entry.visitorName != null)
                          Text('Visitor: ${entry.visitorName}'),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(entry.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: entry.status == 'entry'
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.status.toUpperCase(),
                        style: TextStyle(
                          color: entry.status == 'entry'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateFilterDialog() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _specificDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _specificDate = picked;
      });
      _applySearchFilter();
    }
  }

  Future<void> _showTimeFilterDialog() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _specificTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _specificTime = picked;
      });
      _applySearchFilter();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _specificDate = null;
      _specificTime = null;
      _dateRange = null;
      _selectedResident = 'all';
      _selectedEntryType = 'all';
    });
    _loadEntries();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'rfid':
        return Icons.nfc;
      case 'qr':
        return Icons.qr_code;
      case 'manual':
        return Icons.person;
      default:
        return Icons.door_front_door;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'rfid':
        return Colors.green;
      case 'qr':
        return Colors.purple;
      case 'manual':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter Entries'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Date Range'),
                      subtitle: Text(_dateRange == null
                          ? 'Select range'
                          : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            _dateRange = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedResident,
                      decoration: const InputDecoration(
                        labelText: 'Resident',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Residents')),
                        ..._residents
                            .where((id) => id != 'all')
                            .map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(_residentNames[id] ?? 'Unknown'),
                        )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedResident = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedEntryType,
                      decoration: const InputDecoration(
                        labelText: 'Entry Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'rfid', child: Text('RFID')),
                        DropdownMenuItem(value: 'qr', child: Text('QR Code')),
                        DropdownMenuItem(value: 'manual', child: Text('Manual')),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedEntryType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadEntries();
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}