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

  // ==================== LAYOUT CONSTANTS ====================
  final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
  final double outerPadding = kIsWeb ? 24 : 12;

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

  // ==================== LIVE STREAM ====================
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.history, size: 22, color: Color(0xFFFFF8F0)),
            SizedBox(width: 8),
            Text(
              'Gate History',
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFFF8F0),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFF5F0E8),
              Color(0xFFEDE5D8),
            ],
          ),
        ),
        child: SafeArea(
          child: !_hasLoadedOnce
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFD4C4A8)),
                ),
                SizedBox(height: 16),
                Text('Loading history...',
                    style: TextStyle(color: Color(0xFFB8A99A))),
              ],
            ),
          )
              : _errorMessage != null && _entries.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error,
                    size: 48, color: Color(0xFFD32F2F)),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFF6B5B4F)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4C4A8),
                    foregroundColor: const Color(0xFF6B5B4F),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
              : _entries.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history,
                    size: 70, color: Color(0xFFE0D5C1)),
                SizedBox(height: 16),
                Text(
                  'No gate entries found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B5B4F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your gate access history will appear here',
                  style: TextStyle(
                      color: Color(0xFFB8A99A), fontSize: 12),
                ),
              ],
            ),
          )
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(outerPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: contentMaxWidth),
                child: Column(
                  children: [
                    // ==================== STATS CARD ====================
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding:
                      EdgeInsets.all(kIsWeb ? 14 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFE0D5C1),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4C4A8)
                                .withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                                kIsWeb ? 8 : 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFD4C4A8),
                                  Color(0xFFC4A882)
                                ],
                              ),
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.history,
                                color: const Color(0xFFFFF8F0),
                                size: kIsWeb ? 22 : 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Gate Entries',
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 11 : 12,
                                    color: const Color(
                                        0xFFB8A99A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_entries.length}',
                                  style: TextStyle(
                                    fontSize:
                                    kIsWeb ? 22 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(
                                        0xFF5D4037),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4C4A8)
                                  .withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle,
                                    size: 14,
                                    color:
                                    Color(0xFF8D6E63)),
                                SizedBox(width: 4),
                                Text(
                                  'Last 50',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                    Color(0xFF8D6E63),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================== ENTRIES LIST ====================
                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final timestamp = _parseTimestamp(
                            entry['timestamp']);
                        final entryType =
                            entry['entryType'] ?? 'unknown';
                        final status =
                            entry['status'] ?? 'entry';
                        final visitorName =
                        entry['visitorName'];

                        return Container(
                          margin:
                          const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4C4A8)
                                    .withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(
                                      0xFFE0D5C1),
                                  width: 1),
                            ),
                            child: ListTile(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                              leading: Container(
                                padding:
                                const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end:
                                    Alignment.bottomRight,
                                    colors: [
                                      _getTypeColor(entryType),
                                      _getTypeColor(entryType)
                                          .withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getTypeIcon(entryType),
                                  color: const Color(
                                      0xFFFFF8F0),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                _getEntryTypeLabel(entryType),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B5B4F),
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                        'MMM dd, yyyy • hh:mm a')
                                        .format(timestamp),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFB8A99A),
                                    ),
                                  ),
                                  if (visitorName != null)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(
                                          top: 2),
                                      child: Text(
                                        '👤 $visitorName',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(
                                                0xFFD4C4A8)),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'entry'
                                      ? const Color(0xFF8D6E63)
                                      .withOpacity(0.15)
                                      : const Color(0xFFD32F2F)
                                      .withOpacity(0.15),
                                  borderRadius:
                                  BorderRadius.circular(16),
                                  border: Border.all(
                                    color: status == 'entry'
                                        ? const Color(
                                        0xFF8D6E63)
                                        .withOpacity(0.3)
                                        : const Color(
                                        0xFFD32F2F)
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  status == 'entry' ? '✅' : '❌',
                                  style: const TextStyle(
                                      fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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