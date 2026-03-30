// lib/screens/admin/pending_approvals.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class PendingApprovals extends StatefulWidget {
  const PendingApprovals({super.key});

  @override
  State<PendingApprovals> createState() => _PendingApprovalsState();
}

class _PendingApprovalsState extends State<PendingApprovals> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  List<UserModel> _pendingUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('=== LOADING PENDING USERS ===');

      // First, let's check if we can access Firestore at all
      try {
        print('Testing Firestore connection...');
        DocumentSnapshot testDoc = await _firestore.collection('users').doc('test').get();
        print('Firestore connection successful');
      } catch (e) {
        print('Firestore connection FAILED: $e');
        setState(() {
          _errorMessage = 'Cannot connect to Firestore: $e';
          _isLoading = false;
        });
        return;
      }

      // Get ALL users first to see what's in the database
      print('Fetching all users...');
      QuerySnapshot allUsers = await _firestore.collection('users').get();
      print('Total users found: ${allUsers.docs.length}');

      for (var doc in allUsers.docs) {
        print('User data: ${doc.data()}');
      }

      // Now query for residents with isApproved = false
      print('Querying for pending residents...');
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .where('isApproved', isEqualTo: false)
          .get();

      print('Pending users found: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          print('Pending user: ${doc.data()}');
        }
      }

      setState(() {
        _pendingUsers = snapshot.docs.map((doc) {
          return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();
        _isLoading = false;
      });

      print('=== FINISHED LOADING ===');

    } catch (e) {
      print('ERROR loading pending users: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveUser(UserModel user) async {
    try {
      print('Approving user: ${user.id} - ${user.fullName}');

      await _firestore.collection('users').doc(user.id).update({
        'isApproved': true,
      });

      print('User approved successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} has been approved')),
      );

      _loadPendingUsers();
    } catch (e) {
      print('Error approving user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rejectUser(UserModel user) async {
    try {
      print('Rejecting user: ${user.id} - ${user.fullName}');

      await _firestore.collection('users').doc(user.id).delete();

      print('User rejected successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} has been rejected')),
      );

      _loadPendingUsers();
    } catch (e) {
      print('Error rejecting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingUsers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading pending approvals...'),
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
              onPressed: _loadPendingUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pendingUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No pending approvals',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'All resident applications have been processed',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.home,
                  'House Number',
                  user.houseNumber ?? 'Not provided',
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  Icons.phone,
                  'Phone',
                  user.phoneNumber ?? 'Not provided',
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Registered',
                  DateFormat('MMM dd, yyyy').format(user.createdAt),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveUser(user),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectUser(user),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}