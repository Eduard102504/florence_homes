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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.history, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'Gate Entries',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 18,
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
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            onPressed: _exportToCSV,
            color: const Color(0xFFFFF8F0),
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
          child: Column(
            children: [
              // Filter chips row
              if (_dateRange != null || _selectedResident != 'all' || _selectedEntryType != 'all')
                Container(
                  padding: const EdgeInsets.all(8),
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
                              style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 10),
                            ),
                            deleteIconColor: const Color(0xFFB8A99A),
                            onDeleted: () {
                              setState(() {
                                _dateRange = null;
                              });
                              _loadEntries();
                            },
                          ),
                        if (_selectedResident != 'all')
                          Chip(
                            backgroundColor: Colors.white,
                            label: Text(
                              '👤 ${_residentNames[_selectedResident] ?? 'Unknown'}',
                              style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 10),
                            ),
                            deleteIconColor: const Color(0xFFB8A99A),
                            onDeleted: () {
                              setState(() {
                                _selectedResident = 'all';
                              });
                              _loadEntries();
                            },
                          ),
                        if (_selectedEntryType != 'all')
                          Chip(
                            backgroundColor: Colors.white,
                            label: Text(
                              '🔖 ${_selectedEntryType.toUpperCase()}',
                              style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 10),
                            ),
                            deleteIconColor: const Color(0xFFB8A99A),
                            onDeleted: () {
                              setState(() {
                                _selectedEntryType = 'all';
                              });
                              _loadEntries();
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
                            _loadEntries();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8D6E63),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Clear All', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Stats Cards - Using Wrap to prevent overflow (FIXED)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildStatCard('📊 Total', _entries.length.toString(), Icons.door_front_door, const Color(0xFFD4C4A8), screenWidth),
                    _buildStatCard('📡 RFID', _entries.where((e) => e.entryType == 'rfid').length.toString(), Icons.nfc, const Color(0xFFC4A882), screenWidth),
                    _buildStatCard('📱 QR', _entries.where((e) => e.entryType == 'qr').length.toString(), Icons.qr_code, const Color(0xFFB8A99A), screenWidth),
                  ],
                ),
              ),

              // Entries List
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
                  ),
                )
                    : _entries.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Color(0xFFE0D5C1)),
                      SizedBox(height: 12),
                      Text('No entries found', style: TextStyle(color: Color(0xFFB8A99A), fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Try adjusting your filters', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 12)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _getTypeColor(entry.entryType),
                                  _getTypeColor(entry.entryType).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getTypeIcon(entry.entryType), color: const Color(0xFFFFF8F0), size: 18),
                          ),
                          title: Text(
                            entry.residentName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4C4A8).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  entry.entryType.toUpperCase(),
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF8D6E63)),
                                ),
                              ),
                              if (entry.visitorName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('👤 ${entry.visitorName}', style: const TextStyle(fontSize: 9, color: Color(0xFFB8A99A))),
                                ),
                              Text(
                                '🕐 ${DateFormat('MMM dd, hh:mm a').format(entry.timestamp)}',
                                style: const TextStyle(fontSize: 9, color: Color(0xFFD4C4A8)),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: entry.status == 'entry'
                                  ? const Color(0xFF8D6E63).withOpacity(0.15)
                                  : const Color(0xFFD32F2F).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: entry.status == 'entry'
                                    ? const Color(0xFF8D6E63).withOpacity(0.3)
                                    : const Color(0xFFD32F2F).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              entry.status == 'entry' ? '✅' : '❌',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double screenWidth) {
    // Responsive sizing
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
      case 'rfid': return Icons.nfc;
      case 'qr': return Icons.qr_code;
      case 'manual': return Icons.person;
      default: return Icons.door_front_door;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'rfid': return const Color(0xFFD4C4A8);
      case 'qr': return const Color(0xFFC4A882);
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
              title: const Text('🔍 Filter', style: TextStyle(color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold, fontSize: 15)),
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
                        if (picked != null) {
                          setStateDialog(() {
                            _dateRange = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 4),
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
                        ..._residents
                            .where((id) => id != 'all')
                            .map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(_residentNames[id] ?? 'Unknown', style: const TextStyle(fontSize: 12)),
                        )),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedResident = value!;
                        });
                      },
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
                        DropdownMenuItem(value: 'rfid', child: Text('RFID 📡', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'qr', child: Text('QR Code 📱', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'manual', child: Text('Manual ✏️', style: TextStyle(fontSize: 12))),
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
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadEntries();
                  },
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