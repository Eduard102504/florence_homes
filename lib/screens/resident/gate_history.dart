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

    if (residentId == null) {
      setState(() => _isLoading = false);
      return;
    }

    print('Loading gate history for resident: $residentId');

    try {
      // Get entries without orderBy
      QuerySnapshot snapshot = await _firestore
          .collection('gate_entries')
          .where('residentId', isEqualTo: residentId)
          .limit(50)
          .get();

      print('Found ${snapshot.docs.length} entries');

      // Convert to models
      List<GateEntryModel> entries = snapshot.docs.map((doc) {
        return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // Sort manually (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _entries = entries;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading gate history: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDisplayEntryType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'qr_resident') return 'QR (Self)';
    if (lowerType == 'qr_visitor') return 'QR (Visitor)';
    if (lowerType == 'rfid') return 'RFID';
    if (lowerType == 'manual') return 'Manual Entry';
    return type.toUpperCase();
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
              title: Text(_getDisplayEntryType(entry.entryType)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(entry.timestamp),
                  ),
                  if (entry.visitorName != null)
                    Text('Visitor: ${entry.visitorName}'),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.status == 'success' || entry.status == 'entry'
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (entry.status == 'success' || entry.status == 'entry' ? 'ENTRY' : entry.status).toUpperCase(),
                  style: TextStyle(
                    color: entry.status == 'success' || entry.status == 'entry' ? Colors.green : Colors.red,
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
    final lowerType = type.toLowerCase();
    if (lowerType.contains('rfid')) return Icons.nfc;
    if (lowerType.contains('qr')) return Icons.qr_code;
    if (lowerType == 'manual') return Icons.person;
    return Icons.door_front_door;
  }

  Color _getTypeColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('rfid')) return Colors.green;
    if (lowerType.contains('qr')) return Colors.purple;
    if (lowerType == 'manual') return Colors.orange;
    return Colors.blue;
  }
}