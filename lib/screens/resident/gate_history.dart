import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/gate_entry_model.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class GateHistory extends StatefulWidget {
  const GateHistory({super.key});

  @override
  State<GateHistory> createState() => _GateHistoryState();
}

class _GateHistoryState extends State<GateHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GateEntryModel> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final residentId = authProvider.currentUser?.id;

    if (residentId == null) return;

    QuerySnapshot snapshot = await _firestore
        .collection('gate_entries')
        .where('residentId', isEqualTo: residentId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    setState(() {
      _entries = snapshot.docs.map((doc) {
        return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
      _isLoading = false;
    });
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
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadHistory,
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
          child: _isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8)),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading history...',
                  style: TextStyle(color: Color(0xFFB8A99A)),
                ),
              ],
            ),
          )
              : _entries.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 70, color: Color(0xFFE0D5C1)),
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
                  style: TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                ),
              ],
            ),
          )
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Stats Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
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
                        child: const Icon(Icons.history, color: Color(0xFFFFF8F0), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Gate Entries',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB8A99A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_entries.length}',
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF8D6E63)),
                            const SizedBox(width: 4),
                            Text(
                              'Last 50',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF8D6E63),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Entries List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _getTypeColor(entry.entryType),
                                  _getTypeColor(entry.entryType).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getTypeIcon(entry.entryType),
                              color: const Color(0xFFFFF8F0),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _getEntryTypeLabel(entry.entryType),
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
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(entry.timestamp),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB8A99A),
                                ),
                              ),
                              if (entry.visitorName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '👤 ${entry.visitorName}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFD4C4A8)),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: entry.status == 'entry'
                                  ? const Color(0xFF8D6E63).withOpacity(0.15)
                                  : const Color(0xFFD32F2F).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: entry.status == 'entry'
                                    ? const Color(0xFF8D6E63).withOpacity(0.3)
                                    : const Color(0xFFD32F2F).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              entry.status == 'entry' ? '✅' : '❌',
                              style: const TextStyle(fontSize: 12),
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
    );
  }

  String _getEntryTypeLabel(String type) {
    switch (type) {
      case 'rfid':
        return 'RFID Scan';
      case 'qr':
        return 'QR Code Scan';
      case 'manual':
        return 'Manual Entry';
      default:
        return 'Gate Entry';
    }
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
        return const Color(0xFFD4C4A8);
      case 'qr':
        return const Color(0xFFC4A882);
      case 'manual':
        return const Color(0xFFB8A99A);
      default:
        return const Color(0xFF8D6E63);
    }
  }
}