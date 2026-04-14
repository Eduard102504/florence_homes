import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/qr_service.dart';
import '../../providers/auth_provider.dart';
import 'qr_display_screen.dart';

class MyQRCodes extends StatefulWidget {
  const MyQRCodes({super.key});

  @override
  State<MyQRCodes> createState() => _MyQRCodesState();
}

class _MyQRCodesState extends State<MyQRCodes> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'all';

  // PARA SA DATE/TIME FILTER
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _specificDate;
  TimeOfDay? _specificTime;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
  }

  Future<void> _loadQRCodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final residentId = authProvider.currentUser?.id;

      print('Loading QR codes for resident: $residentId');

      if (residentId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      QuerySnapshot snapshot = await _firestore
          .collection('visitor_qrs')
          .where('residentId', isEqualTo: residentId)
          .get();
      print('Found ${snapshot.docs.length} QR codes');

      List<Map<String, dynamic>> qrList = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      qrList.sort((a, b) {
        DateTime aDate = DateTime.parse(a['generatedAt']);
        DateTime bDate = DateTime.parse(b['generatedAt']);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _qrCodes = qrList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading QR codes: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredQRCodes() {
    List<Map<String, dynamic>> filtered = List.from(_qrCodes);

    // Filter by status
    switch (_filter) {
      case 'active':
        filtered = filtered.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isAfter(DateTime.now());
        }).toList();
        break;
      case 'expired':
        filtered = filtered.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isBefore(DateTime.now());
        }).toList();
        break;
      case 'used':
        filtered = filtered.where((qr) => qr['isUsed'] == true).toList();
        break;
      default:
        break;
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((qr) {
        return qr['visitorName']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      }).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((qr) {
        DateTime generatedAt = DateTime.parse(qr['generatedAt']);
        return generatedAt.isAfter(_startDate!) &&
            generatedAt.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Filter by specific date
    if (_specificDate != null) {
      filtered = filtered.where((qr) {
        DateTime generatedAt = DateTime.parse(qr['generatedAt']);
        return generatedAt.year == _specificDate!.year &&
            generatedAt.month == _specificDate!.month &&
            generatedAt.day == _specificDate!.day;
      }).toList();
    }

    // Filter by specific time
    if (_specificTime != null) {
      filtered = filtered.where((qr) {
        DateTime generatedAt = DateTime.parse(qr['generatedAt']);
        return generatedAt.hour == _specificTime!.hour &&
            generatedAt.minute == _specificTime!.minute;
      }).toList();
    }

    return filtered;
  }

  String _getStatus(Map<String, dynamic> qr) {
    DateTime expiresAt = DateTime.parse(qr['expiresAt']);

    if (qr['isUsed']) return 'Used';
    if (expiresAt.isBefore(DateTime.now())) return 'Expired';

    Duration remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours < 1) return 'Expiring soon';
    return 'Active';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Expiring soon':
        return Colors.orange;
      case 'Expired':
        return Colors.red;
      case 'Used':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _specificDate = null;
        _specificTime = null;
      });
    }
  }

  Future<void> _selectSpecificDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _specificDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _specificDate = picked;
        _startDate = null;
        _endDate = null;
      });
    }
  }

  Future<void> _selectSpecificTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _specificTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _specificTime = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _specificDate = null;
      _specificTime = null;
      _searchQuery = '';
      _filter = 'all';
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter QR Codes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.green),
              title: const Text('Date Range'),
              subtitle: _startDate != null
                  ? Text('${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}')
                  : const Text('Select a date range'),
              onTap: () {
                Navigator.pop(context);
                _selectDateRange();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('Specific Date'),
              subtitle: _specificDate != null
                  ? Text(DateFormat('MMM dd, yyyy').format(_specificDate!))
                  : const Text('Select a specific date'),
              onTap: () {
                Navigator.pop(context);
                _selectSpecificDate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.purple),
              title: const Text('Specific Time'),
              subtitle: _specificTime != null
                  ? Text(_specificTime!.format(context))
                  : const Text('Select a specific time'),
              onTap: () {
                Navigator.pop(context);
                _selectSpecificTime();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.red),
              title: const Text('Clear All Filters'),
              onTap: () {
                Navigator.pop(context);
                _clearFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredQRCodes = _getFilteredQRCodes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Codes'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQRCodes,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by visitor name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
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
              },
            ),
          ),

          // Filter Chips (status)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filter == 'all',
                    onSelected: (selected) {
                      setState(() => _filter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Active'),
                    selected: _filter == 'active',
                    onSelected: (selected) {
                      setState(() => _filter = 'active');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Expired'),
                    selected: _filter == 'expired',
                    onSelected: (selected) {
                      setState(() => _filter = 'expired');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Used'),
                    selected: _filter == 'used',
                    onSelected: (selected) {
                      setState(() => _filter = 'used');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredQRCodes.length} QR codes found',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (_searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // QR Codes List
          Expanded(
            child: filteredQRCodes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _startDate != null || _specificDate != null
                        ? 'No matching QR codes'
                        : 'No QR codes yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _startDate != null || _specificDate != null)
                    const SizedBox(height: 16),
                  if (_searchQuery.isNotEmpty || _startDate != null || _specificDate != null)
                    ElevatedButton(
                      onPressed: _clearFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredQRCodes.length,
              itemBuilder: (context, index) {
                final qr = filteredQRCodes[index];
                final status = _getStatus(qr);
                final statusColor = _getStatusColor(status);
                final expiresAt = DateTime.parse(qr['expiresAt']);
                final generatedAt = DateTime.parse(qr['generatedAt']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QRDisplayScreen(
                            qrData: qr['qrCodeData'] ?? qr['id'],
                            visitorName: qr['visitorName'],
                            isSavedQR: true,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.qr_code,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      qr['visitorName'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'For: ${qr['residentName']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expires: ${DateFormat('MMM dd, yyyy • hh:mm a').format(expiresAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Generated: ${DateFormat('MMM dd, yyyy • hh:mm a').format(generatedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}