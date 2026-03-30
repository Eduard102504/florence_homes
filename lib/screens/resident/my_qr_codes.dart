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
          .orderBy('generatedAt', descending: true)
          .get();

      print('Found ${snapshot.docs.length} QR codes');

      setState(() {
        _qrCodes = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
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
    switch (_filter) {
      case 'active':
        return _qrCodes.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isAfter(DateTime.now());
        }).toList();
      case 'expired':
        return _qrCodes.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isBefore(DateTime.now());
        }).toList();
      case 'used':
        return _qrCodes.where((qr) => qr['isUsed'] == true).toList();
      default:
        return _qrCodes;
    }
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

  @override
  Widget build(BuildContext context) {
    final filteredQRCodes = _getFilteredQRCodes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Codes'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQRCodes,
          ),
        ],
      ),
      body: _buildBody(filteredQRCodes),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> filteredQRCodes) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your QR codes...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadQRCodes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_qrCodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No QR Codes Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate visitor QR codes from the home screen',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter Chips
        Padding(
          padding: const EdgeInsets.all(16.0),
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
                  'No ${_filter == 'all' ? '' : _filter} QR codes',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
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
                              'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(qr['generatedAt']))}',
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
    );
  }
}