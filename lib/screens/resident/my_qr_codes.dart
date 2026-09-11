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
        return const Color(0xFF4CAF50);
      case 'Expiring soon':
        return const Color(0xFFFF9800);
      case 'Expired':
        return const Color(0xFFD32F2F);
      case 'Used':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredQRCodes = _getFilteredQRCodes();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.qr_code, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'My QR Codes',
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
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadQRCodes,
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
          child: _buildBody(filteredQRCodes, screenWidth),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> filteredQRCodes, double screenWidth) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your QR codes...',
              style: TextStyle(color: Color(0xFFB8A99A)),
            ),
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
              onPressed: _loadQRCodes,
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

    if (_qrCodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code,
                size: 70,
                color: Color(0xFFD4C4A8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No QR Codes Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5B4F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate visitor QR codes from the home screen',
              style: TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats Card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Color(0xFFFFF8F0), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total QR Codes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB8A99A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_qrCodes.length}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C4A8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _filter == 'all' ? 'All' : _filter,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8D6E63),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter Chips
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Expired', 'expired'),
                const SizedBox(width: 8),
                _buildFilterChip('Used', 'used'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

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
                  color: const Color(0xFFE0D5C1),
                ),
                const SizedBox(height: 12),
                Text(
                  'No ${_filter == 'all' ? '' : _filter} QR codes',
                  style: const TextStyle(
                    color: Color(0xFFB8A99A),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredQRCodes.length,
            itemBuilder: (context, index) {
              final qr = filteredQRCodes[index];
              final status = _getStatus(qr);
              final statusColor = _getStatusColor(status);
              final expiresAt = DateTime.parse(qr['expiresAt']);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
                  ),
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
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFD4C4A8),
                                      const Color(0xFFC4A882),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.qr_code,
                                  color: Color(0xFFFFF8F0),
                                  size: 24,
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B5B4F),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'For: ${qr['residentName']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFFB8A99A),
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
                                  status == 'Expiring soon' ? '⚠️ $status' : status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFFB8A99A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expires: ${DateFormat('MMM dd, hh:mm a').format(expiresAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB8A99A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Color(0xFFB8A99A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(qr['generatedAt']))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB8A99A),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: _filter == value ? const Color(0xFFFFF8F0) : const Color(0xFF6B5B4F),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: _filter == value,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFD4C4A8),
      checkmarkColor: const Color(0xFFFFF8F0),
      side: BorderSide(
        color: _filter == value ? const Color(0xFFD4C4A8) : const Color(0xFFE0D5C1),
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}