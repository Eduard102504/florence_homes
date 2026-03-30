import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/gate_entry_model.dart';

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
      _isLoading = false;
    });
  }

  Future<void> _exportToCSV() async {
    List<List<dynamic>> rows = [
      ['Date', 'Time', 'Resident', 'Type', 'Visitor', 'Status']
    ];

    for (var entry in _entries) {
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

          // Stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Entries',
                    _entries.length.toString(),
                    Icons.door_front_door,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'RFID Scans',
                    _entries.where((e) => e.entryType == 'rfid').length.toString(),
                    Icons.nfc,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'QR Scans',
                    _entries.where((e) => e.entryType == 'qr').length.toString(),
                    Icons.qr_code,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // Entries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
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
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
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