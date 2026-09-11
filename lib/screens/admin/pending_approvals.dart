// lib/screens/admin/pending_approvals.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/email_service.dart';
import '../../models/user_model.dart';

class PendingApprovals extends StatefulWidget {
  const PendingApprovals({super.key});

  @override
  State<PendingApprovals> createState() => _PendingApprovalsState();
}

class _PendingApprovalsState extends State<PendingApprovals> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserModel> _pendingUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _rejectionReason;
  bool _isProcessing = false;

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
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .where('isApproved', isEqualTo: false)
          .get();

      setState(() {
        _pendingUsers = snapshot.docs.map((doc) {
          return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveUser(UserModel user) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _firestore.collection('users').doc(user.id).update({
        'isApproved': true,
      });

      // Send approval email
      bool emailSent = await EmailService.sendApprovalEmail(user.email, user.fullName);

      if (emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.fullName} has been approved and notified via email'),
            backgroundColor: const Color(0xFF8D6E63),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.fullName} approved but email notification failed'),
            backgroundColor: const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving user: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showRejectionDialog(UserModel user) async {
    _rejectionReason = null;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Reject Registration',
            style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject ${user.fullName}\'s registration?',
                style: const TextStyle(color: Color(0xFF8D6E63)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason (optional):',
                style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) {
                  _rejectionReason = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  hintStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectUser(user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejectUser(UserModel user) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Send rejection email before deleting
      bool emailSent = await EmailService.sendRejectionEmail(
          user.email,
          user.fullName,
          _rejectionReason
      );

      // Delete user from Firestore
      await _firestore.collection('users').doc(user.id).delete();

      if (emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${user.fullName} has been rejected and notified via email'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${user.fullName} rejected but email notification failed'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadPendingUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting user: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.pending_actions, size: 24, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 10),
            const Text(
              'Pending Approvals',
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
            onPressed: _isProcessing ? null : _loadPendingUsers,
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
          child: _isProcessing
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC4A882)),
                ),
                SizedBox(height: 16),
                Text('Processing...', style: TextStyle(color: Color(0xFF8D6E63))),
              ],
            ),
          )
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8))),
            SizedBox(height: 16),
            Text('Loading pending approvals...', style: TextStyle(color: Color(0xFFB8A99A))),
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
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB8A99A))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
              ),
              child: const Text('Retry 🔄'),
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
            Icon(Icons.check_circle, size: 60, color: Color(0xFF8D6E63)),
            SizedBox(height: 16),
            Text('🎉 No pending approvals!', style: TextStyle(fontSize: 16, color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('All residents have been processed', style: TextStyle(color: Color(0xFFB8A99A), fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                              const Color(0xFFFF9800).withOpacity(0.2),
                              const Color(0xFFFF9800).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, size: 32, color: Color(0xFFFF9800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                            const SizedBox(height: 2),
                            Text(user.email, style: TextStyle(color: const Color(0xFFB8A99A), fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                        ),
                        child: const Text('⏳ PENDING', style: TextStyle(color: Color(0xFFFF9800), fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE0D5C1), height: 20),
                  _buildInfoRow(Icons.home, '🏠 House', user.houseNumber ?? 'Not provided'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.phone, '📱 Phone', user.phoneNumber ?? 'Not provided'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.calendar_today, '📅 Registered', DateFormat('MMM dd, yyyy').format(user.createdAt)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _approveUser(user),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8D6E63),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : () => _showRejectionDialog(user),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF6B5B4F)))),
      ],
    );
  }
}