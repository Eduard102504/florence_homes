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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate History'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No gate entries found'),
            SizedBox(height: 8),
            Text(
              'Your gate access history will appear here',
              style: TextStyle(color: Colors.grey),
            ),
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
              title: Text(entry.entryType.toUpperCase()),
              subtitle: Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(entry.timestamp),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.status == 'entry'
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.status.toUpperCase(),
                  style: TextStyle(
                    color: entry.status == 'entry' ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
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
}