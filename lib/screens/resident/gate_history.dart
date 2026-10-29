// lib/screens/admin/gate_history.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import 'dart:async';

class GateHistory extends StatefulWidget {
  const GateHistory({super.key});

  @override
  State<GateHistory> createState() => _GateHistoryState();
}

class _GateHistoryState extends State<GateHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _entries = [];
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _sub;

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate().toLocal();
    if (timestamp is DateTime) return timestamp.toLocal();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).toLocal();
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStream());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startStream() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final residentId = authProvider.currentUser?.id;

    if (residentId == null) {
      setState(() {
        _errorMessage = 'User not logged in';
        _hasLoadedOnce = true;
      });
      return;
    }

    _sub?.cancel();
    _sub = _firestore
        .collection('gate_entries')
        .where('residentId', isEqualTo: residentId)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
        final entries = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        entries.sort((a, b) {
          final ta = _parseTimestamp(a['timestamp']);
          final tb = _parseTimestamp(b['timestamp']);
          return tb.compareTo(ta);
        });

        if (mounted) {
          setState(() {
            _entries = entries;
            _hasLoadedOnce = true;
            _errorMessage = null;
          });
        }
      },
      onError: (e) {
        print('History stream error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error: $e';
            _hasLoadedOnce = true;
          });
        }
      },
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: _buildWebContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(child: _buildMobileContent()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🖥️ WEB COMPONENTS
  // ============================================================

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF5D4037),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.home_work, size: 48, color: Color(0xFFFFF8F0)),
          const SizedBox(height: 12),
          const Text('Florence Homes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8F0),
                  letterSpacing: 1)),
          const Text('Resident Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.qr_code_scanner, 'My QR Code',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History',
              isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.person, 'Profile',
              onTap: () => Navigator.pop(context)),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Back to Dashboard',
                style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title,
      {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? const Color(0xFFD4C4A8).withOpacity(0.15)
            : Colors.transparent,
        leading: Icon(icon,
            color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title,
            style: TextStyle(
                color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Gate History',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3))),
            child: Row(
              children: const [
                Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50)),
                SizedBox(width: 6),
                Text('LIVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    if (!_hasLoadedOnce) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    }
    if (_errorMessage != null && _entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFF5D4037)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startStream,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D5C1))),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 70, color: Color(0xFFE0D5C1)),
              SizedBox(height: 16),
              Text('No gate entries found',
                  style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5D4037),
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Your gate access history will appear here',
                  style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D5C1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF5D4037),
                      Color(0xFF8D6E63)
                    ]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.history,
                    color: Color(0xFFFFF8F0), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Gate Entries',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8D6E63),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('${_entries.length}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037))),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF8D6E63)),
                    SizedBox(width: 4),
                    Text('Last 50',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8D6E63),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Entries
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _entries.length,
          itemBuilder: (context, index) => _buildWebEntryRow(_entries[index]),
        ),
      ],
    );
  }

  Widget _buildWebEntryRow(Map<String, dynamic> entry) {
    final timestamp = _parseTimestamp(entry['timestamp']);
    final entryType = entry['entryType'] ?? 'unknown';
    final status = entry['status'] ?? 'entry';
    final visitorName = entry['visitorName'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0D5C1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _getTypeColor(entryType),
                  _getTypeColor(entryType).withOpacity(0.7)
                ]),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_getTypeIcon(entryType),
                color: const Color(0xFFFFF8F0), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getEntryTypeLabel(entryType),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                        fontSize: 15)),
                if (visitorName != null)
                  Text('👤 $visitorName',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D6E63))),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF8D6E63))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: status == 'entry'
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFFD32F2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: status == 'entry'
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : const Color(0xFFD32F2F).withOpacity(0.3))),
            child: Text(status == 'entry' ? '🟢 IN' : '🔴 OUT',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status == 'entry'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.history,
                  size: 120, color: Colors.white.withOpacity(0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Gate History',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4CAF50))),
                    child: const Text('LIVE',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Access Log',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    if (!_hasLoadedOnce) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    }
    if (_errorMessage != null && _entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Color(0xFFD32F2F)),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFF5D4037)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startStream,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white),
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
            Icon(Icons.history, size: 70, color: Color(0xFFD4C4A8)),
            SizedBox(height: 16),
            Text('No gate entries found',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Your gate access history will appear here',
                style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF5D4037),
                        Color(0xFF8D6E63)
                      ]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.history,
                      color: Color(0xFFFFF8F0), size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Gate Entries',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${_entries.length}',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037))),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD4C4A8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle,
                          size: 12, color: Color(0xFF8D6E63)),
                      SizedBox(width: 4),
                      Text('Last 50',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Entries
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (context, index) =>
                _buildMobileEntryCard(_entries[index]),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobileEntryCard(Map<String, dynamic> entry) {
    final timestamp = _parseTimestamp(entry['timestamp']);
    final entryType = entry['entryType'] ?? 'unknown';
    final status = entry['status'] ?? 'entry';
    final visitorName = entry['visitorName'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _getTypeColor(entryType),
                        _getTypeColor(entryType).withOpacity(0.7)
                      ]),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getTypeIcon(entryType),
                      color: const Color(0xFFFFF8F0), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getEntryTypeLabel(entryType),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                              fontSize: 14)),
                      if (visitorName != null)
                        Text('👤 $visitorName',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF8D6E63))),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: status == 'entry'
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : const Color(0xFFD32F2F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: status == 'entry'
                              ? const Color(0xFF4CAF50).withOpacity(0.3)
                              : const Color(0xFFD32F2F).withOpacity(0.3))),
                  child: Text(status == 'entry' ? '🟢 IN' : '🔴 OUT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status == 'entry'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD32F2F))),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 24),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 14, color: Color(0xFFD4C4A8)),
                const SizedBox(width: 8),
                Text(DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED HELPERS ====================
  String _getEntryTypeLabel(String type) {
    switch (type) {
      case 'rfid':
        return 'RFID Scan';
      case 'uhf_rfid':
        return 'UHF RFID Scan';
      case 'qr':
        return 'QR Code Scan';
      case 'qr_visitor':
        return 'Visitor QR Code';
      case 'manual':
        return 'Manual Entry';
      default:
        return 'Gate Entry';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'rfid':
      case 'uhf_rfid':
        return Icons.nfc;
      case 'qr':
      case 'qr_visitor':
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
      case 'uhf_rfid':
        return const Color(0xFFD4C4A8);
      case 'qr':
      case 'qr_visitor':
        return const Color(0xFFC4A882);
      case 'manual':
        return const Color(0xFFB8A99A);
      default:
        return const Color(0xFF8D6E63);
    }
  }
}