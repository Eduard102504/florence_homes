import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GateEntriesHistory extends StatefulWidget {
  const GateEntriesHistory({super.key});

  @override
  State<GateEntriesHistory> createState() => _GateEntriesHistoryState();
}

class _GateEntriesHistoryState extends State<GateEntriesHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _allEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTimeRange? _dateRange;
  String _selectedResident = 'all';
  String _selectedEntryType = 'all';
  List<String> _residents = [];
  Map<String, String> _residentNames = {};
  bool _isExporting = false;

  // FIXED: Convert UTC timestamp to LOCAL time
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    DateTime utcTime;
    if (timestamp is Timestamp) {
      utcTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      utcTime = timestamp;
    } else if (timestamp is String) {
      utcTime = DateTime.parse(timestamp);
    } else {
      return DateTime.now();
    }

    // Convert UTC to LOCAL time (this fixes the 8-hour difference)
    return utcTime.toLocal();
  }

  // Helper to get timestamp from entry (tries multiple field names)
  DateTime _getEntryTimestamp(Map<String, dynamic> entry) {
    // Try different possible field names
    if (entry['timestamp'] != null) {
      return _parseTimestamp(entry['timestamp']);
    }
    if (entry['createdAt'] != null) {
      return _parseTimestamp(entry['createdAt']);
    }
    if (entry['date'] != null) {
      return _parseTimestamp(entry['date']);
    }
    if (entry['time'] != null) {
      return _parseTimestamp(entry['time']);
    }
    return DateTime.now();
  }

  List<Map<String, dynamic>> _sortEntriesByDate(List<Map<String, dynamic>> entries) {
    entries.sort((a, b) {
      DateTime timeA = _getEntryTimestamp(a);
      DateTime timeB = _getEntryTimestamp(b);
      return timeB.compareTo(timeA);
    });
    return entries;
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allEntries);

    if (_selectedResident != 'all') {
      filtered = filtered.where((entry) => entry['residentId'] == _selectedResident).toList();
    }

    if (_selectedEntryType != 'all') {
      filtered = filtered.where((entry) => entry['entryType'] == _selectedEntryType).toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((entry) {
        DateTime timestamp = _getEntryTimestamp(entry);
        return timestamp.isAfter(_dateRange!.start) &&
            timestamp.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    filtered = _sortEntriesByDate(filtered);

    setState(() {
      _entries = filtered;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _loadEntries();
  }

  Future<void> _loadResidents() async {
    try {
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
    } catch (e) {
      print('Error loading residents: $e');
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all entries and sort locally
      QuerySnapshot snapshot = await _firestore
          .collection('gate_entries')
          .get();

      List<Map<String, dynamic>> allEntries = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort locally by timestamp (newest first)
      allEntries.sort((a, b) {
        DateTime timeA = _getEntryTimestamp(a);
        DateTime timeB = _getEntryTimestamp(b);
        return timeB.compareTo(timeA);
      });

      setState(() {
        _allEntries = allEntries;
        _entries = List.from(allEntries);
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading entries: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _updateFilters() {
    _applyFilters();
  }

  String _getEntryTypeDisplay(String? type) {
    switch (type) {
      case 'uhf_rfid':
      case 'rfid':
        return 'RFID';
      case 'qr_visitor':
        return 'QR Visitor';
      case 'manual':
        return 'Manual Entry';
      default:
        return type?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  // Generate PDF Report
  Future<void> _exportToPDF() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export'), backgroundColor: Color(0xFFFF9800)),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      int totalEntries = _entries.length;
      int rfidEntries = _entries.where((e) => e['entryType'] == 'uhf_rfid' || e['entryType'] == 'rfid').length;
      int qrEntries = _entries.where((e) => e['entryType'] == 'qr_visitor').length;
      int manualEntries = _entries.where((e) => e['entryType'] == 'manual').length;

      String dateRange = _dateRange != null
          ? '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
          : 'All Time';

      String residentFilter = _selectedResident != 'all'
          ? _residentNames[_selectedResident] ?? 'Selected Resident'
          : 'All Residents';

      String entryTypeFilter = _selectedEntryType != 'all'
          ? _selectedEntryType.toUpperCase()
          : 'All Types';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 100),
                    pw.Icon(pw.IconData(0xe3c9), size: 80, color: PdfColors.brown),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Florence Homes',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.brown,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Gate Entry Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.grey,
                      ),
                    ),
                    pw.SizedBox(height: 40),
                    pw.Text(
                      'Generated: ${DateFormat('MMMM dd, yyyy hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Report Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date Range:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateRange, style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Resident Filter:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(residentFilter, style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Entry Type Filter:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(entryTypeFilter, style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Divider(),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Entries:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(totalEntries.toString(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.brown)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('RFID Scans:', style: pw.TextStyle(fontSize: 12)),
                        pw.Text(rfidEntries.toString(), style: pw.TextStyle(fontSize: 12, color: PdfColors.green)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('QR Visitor Scans:', style: pw.TextStyle(fontSize: 12)),
                        pw.Text(qrEntries.toString(), style: pw.TextStyle(fontSize: 12, color: PdfColors.purple)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Manual Entries:', style: pw.TextStyle(fontSize: 12)),
                        pw.Text(manualEntries.toString(), style: pw.TextStyle(fontSize: 12, color: PdfColors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Generated by: Florence Homes Gate System', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ];
          },
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.landscape,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text('Gate Entry Details', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Date', 'Time', 'Resident', 'Type', 'Visitor', 'Status'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.brown100),
                cellAlignment: pw.Alignment.centerLeft,
                data: _entries.map((entry) {
                  DateTime timestamp = _getEntryTimestamp(entry);
                  return [
                    DateFormat('yyyy-MM-dd').format(timestamp),
                    DateFormat('hh:mm:ss a').format(timestamp),
                    entry['residentName'] ?? 'Unknown',
                    _getEntryTypeDisplay(entry['entryType']),
                    entry['visitorName'] ?? '-',
                    entry['status']?.toUpperCase() ?? 'ENTRY',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total Records: ${_entries.length}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/gate_history_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Florence Homes - Gate Entry Report');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generated and shared successfully'), backgroundColor: Color(0xFF8D6E63)),
      );
    } catch (e) {
      print('PDF generation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: const Color(0xFFD32F2F)),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCSV() async {
    if (_entries.isEmpty) return;

    List<List<dynamic>> rows = [
      ['Date', 'Time', 'Resident', 'Type', 'Visitor', 'Status']
    ];

    for (var entry in _entries) {
      DateTime timestamp = _getEntryTimestamp(entry);
      rows.add([
        DateFormat('yyyy-MM-dd').format(timestamp),
        DateFormat('hh:mm:ss a').format(timestamp),
        entry['residentName'] ?? 'Unknown',
        _getEntryTypeDisplay(entry['entryType']),
        entry['visitorName'] ?? '-',
        entry['status']?.toUpperCase() ?? 'ENTRY',
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.history, size: 20, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'Gate History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 15,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, size: 20),
            onPressed: _showFilterDialog,
            color: const Color(0xFFFFF8F0),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'csv') {
                _exportToCSV();
              } else if (value == 'pdf') {
                _exportToPDF();
              }
            },
            icon: _isExporting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)),
              ),
            )
                : const Icon(Icons.download, color: Color(0xFFFFF8F0)),
            color: const Color(0xFFFFF8F0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0D5C1)),
            ),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 18, color: Color(0xFF8D6E63)),
                    SizedBox(width: 8),
                    Text('Export CSV', style: TextStyle(fontSize: 13, color: Color(0xFF6B5B4F))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFFD32F2F)),
                    SizedBox(width: 8),
                    Text('Export PDF', style: TextStyle(fontSize: 13, color: Color(0xFF6B5B4F))),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadEntries,
            color: const Color(0xFFFFF8F0),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF8F0),
              const Color(0xFFF5F0E8),
              const Color(0xFFEDE5D8),
            ],
          ),
        ),
        child: SafeArea(
          child: _buildBody(screenWidth),
        ),
      ),
    );
  }

  Widget _buildBody(double screenWidth) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
            ),
            SizedBox(height: 16),
            Text('Loading gate entries...', style: TextStyle(color: Color(0xFFB8A99A))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFF8D6E63))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEntries,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 70, color: Color(0xFFE0D5C1)),
            SizedBox(height: 16),
            Text(
              'No gate entries found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF6B5B4F)),
            ),
            SizedBox(height: 8),
            Text(
              'Scan RFID tags or generate QR codes to see entries',
              style: TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter chips
        if (_dateRange != null || _selectedResident != 'all' || _selectedEntryType != 'all')
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 14, color: Color(0xFF8D6E63)),
                  const SizedBox(width: 6),
                  if (_dateRange != null)
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '📅 ${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                        style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() { _dateRange = null; });
                        _updateFilters();
                      },
                    ),
                  if (_selectedResident != 'all')
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '👤 ${_residentNames[_selectedResident] ?? 'Unknown'}',
                        style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() { _selectedResident = 'all'; });
                        _updateFilters();
                      },
                    ),
                  if (_selectedEntryType != 'all')
                    Chip(
                      backgroundColor: Colors.white,
                      label: Text(
                        '🔖 ${_selectedEntryType.toUpperCase().replaceFirst('UHF_', '')}',
                        style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 11),
                      ),
                      deleteIconColor: const Color(0xFFB8A99A),
                      onDeleted: () {
                        setState(() { _selectedEntryType = 'all'; });
                        _updateFilters();
                      },
                    ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                        _selectedResident = 'all';
                        _selectedEntryType = 'all';
                      });
                      _updateFilters();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8D6E63),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),

        // Stats Cards
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard('📊 Total', _entries.length.toString(), Icons.door_front_door, const Color(0xFFD4C4A8), screenWidth),
              _buildStatCard('📡 RFID', _entries.where((e) => e['entryType'] == 'uhf_rfid' || e['entryType'] == 'rfid').length.toString(), Icons.nfc, const Color(0xFFC4A882), screenWidth),
              _buildStatCard('👥 Visitors', _entries.where((e) => e['entryType'] == 'qr_visitor').length.toString(), Icons.people, const Color(0xFFB8A99A), screenWidth),
            ],
          ),
        ),

        // Entries List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              DateTime timestamp = _getEntryTimestamp(entry);
              String entryType = entry['entryType'] ?? 'unknown';
              String residentName = entry['residentName'] ?? 'Unknown';
              String status = entry['status'] ?? 'entry';
              String? visitorName = entry['visitorName'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4C4A8).withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getTypeColor(entryType),
                            _getTypeColor(entryType).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(entryType),
                        color: const Color(0xFFFFF8F0),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      residentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5B4F),
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4C4A8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getEntryTypeDisplay(entryType),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                        ),
                        if (visitorName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '👤 $visitorName',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFB8A99A)),
                            ),
                          ),
                        Text(
                          '🕐 ${DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD4C4A8)),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'entry'
                            ? const Color(0xFF8D6E63).withOpacity(0.15)
                            : const Color(0xFFD32F2F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: status == 'entry'
                              ? const Color(0xFF8D6E63).withOpacity(0.3)
                              : const Color(0xFFD32F2F).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        status == 'entry' ? '✅' : '❌',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double screenWidth) {
    double cardWidth = screenWidth < 600 ? (screenWidth / 3) - 16 : 100;
    double iconSize = screenWidth < 600 ? 14 : 16;
    double fontSize = screenWidth < 600 ? 11 : 13;
    double labelSize = screenWidth < 600 ? 8 : 9;

    return Container(
      width: cardWidth.clamp(80, 120),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: labelSize, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'rfid': case 'uhf_rfid': return Icons.nfc;
      case 'qr_visitor': return Icons.qr_code;
      case 'manual': return Icons.person;
      default: return Icons.door_front_door;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'rfid': case 'uhf_rfid': return const Color(0xFFD4C4A8);
      case 'qr_visitor': return const Color(0xFFC4A882);
      case 'manual': return const Color(0xFFB8A99A);
      default: return const Color(0xFF8D6E63);
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('🔍 Filter Entries', style: TextStyle(color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold, fontSize: 15)),
              backgroundColor: const Color(0xFFFFF8F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('📅 Date Range', style: TextStyle(color: Color(0xFF6B5B4F), fontSize: 12)),
                      subtitle: Text(
                        _dateRange == null
                            ? 'Select range'
                            : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                        style: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Color(0xFFD4C4A8), size: 16),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFFD4C4A8),
                                  onPrimary: Color(0xFFFFF8F0),
                                  surface: Color(0xFFFFF8F0),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) setStateDialog(() => _dateRange = picked);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedResident,
                      decoration: InputDecoration(
                        labelText: '👤 Resident',
                        labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Residents', style: TextStyle(fontSize: 12))),
                        ..._residents.where((id) => id != 'all').map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(_residentNames[id] ?? 'Unknown', style: const TextStyle(fontSize: 12)),
                        )),
                      ],
                      onChanged: (value) => setStateDialog(() => _selectedResident = value!),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEntryType,
                      decoration: InputDecoration(
                        labelText: '🔖 Entry Type',
                        labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'uhf_rfid', child: Text('RFID 📡', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'qr_visitor', child: Text('QR Visitor 📱', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'manual', child: Text('Manual Entry ✏️', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (value) => setStateDialog(() => _selectedEntryType = value!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () { Navigator.pop(context); _updateFilters(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4C4A8),
                    foregroundColor: const Color(0xFF6B5B4F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}