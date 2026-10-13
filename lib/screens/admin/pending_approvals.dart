import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  List<UserModel> _filteredUsers = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _rejectionReason;
  bool _isProcessing = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      final list = snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      list.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      setState(() {
        _pendingUsers = list;
        _applyFiltersInternal();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFiltersInternal() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_pendingUsers);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredUsers = _pendingUsers.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.residentId?.toLowerCase().contains(q) ?? false) ||
            (u.houseNumber?.toLowerCase().contains(q) ?? false) ||
            (u.phoneNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_currentPage > _totalPages) {
      _currentPage = _totalPages < 1 ? 1 : _totalPages;
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
      _applyFiltersInternal();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;
      _applyFiltersInternal();
    });
  }

  int get _totalPages {
    if (_pageSize == 0) return 1;
    if (_filteredUsers.isEmpty) return 1;
    return ((_filteredUsers.length - 1) ~/ _pageSize) + 1;
  }

  List<UserModel> get _paginatedUsers {
    if (_pageSize == 0) return _filteredUsers;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _filteredUsers.length) return [];
    final end = (start + _pageSize).clamp(0, _filteredUsers.length);
    return _filteredUsers.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _changePageSize(int newSize) {
    setState(() {
      _pageSize = newSize;
      _currentPage = 1;
    });
  }

  // ==================== APPROVE ====================
  // 🔥 CHANGED — password now read from `users_private`
  Future<void> _approveUser(UserModel user) async {
    setState(() => _isProcessing = true);

    try {
      // Read public user doc (for residentId, email, hasRealEmail)
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final data = userDoc.data() as Map<String, dynamic>;

      final residentId = data['residentId'] as String?;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      // 🔥 Read password from private collection
      String? plaintextPassword;
      try {
        final privateDoc = await _firestore
            .collection('users_private')
            .doc(user.id)
            .get();
        if (privateDoc.exists) {
          plaintextPassword =
          (privateDoc.data()?['plaintextPassword']) as String?;
        }
      } catch (e) {
        print('⚠️ Could not read users_private: $e');
      }

      // Mark as approved
      await _firestore.collection('users').doc(user.id).update({
        'isApproved': true,
      });

      bool emailSent = false;
      String message;

      if (hasRealEmail &&
          storedEmail.isNotEmpty &&
          residentId != null &&
          plaintextPassword != null) {
        emailSent = await EmailService.sendResidentCredentialsEmail(
          email: storedEmail,
          fullName: user.fullName,
          residentId: residentId,
          password: plaintextPassword,
        );

        // 🔥 Delete the private doc after successful email
        if (emailSent) {
          try {
            await _firestore
                .collection('users_private')
                .doc(user.id)
                .delete();
          } catch (e) {
            print('⚠️ Could not delete users_private: $e');
          }
        }

        message = emailSent
            ? '✅ ${user.fullName} approved. Credentials emailed.'
            : '✅ Approved but email failed. Credentials: $residentId / $plaintextPassword';
      } else if (!hasRealEmail || storedEmail.isEmpty) {
        message =
        '✅ ${user.fullName} approved. No email on file — credentials: $residentId / ${plaintextPassword ?? "N/A"}';
      } else {
        emailSent = await EmailService.sendApprovalEmail(
          storedEmail,
          user.fullName,
        );
        message = emailSent
            ? '✅ ${user.fullName} approved and notified via email.'
            : '✅ ${user.fullName} approved but email failed.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF8D6E63),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }

      _loadPendingUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showRejectionDialog(UserModel user) async {
    _rejectionReason = null;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Reject Registration',
            style: TextStyle(
                color: Color(0xFF5D4037), fontWeight: FontWeight.bold),
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
                style: TextStyle(
                    color: Color(0xFF5D4037), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) {
                  _rejectionReason = value;
                },
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  hintStyle: const TextStyle(
                      color: Color(0xFFB8A99A), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: Color(0xFFC4A882), width: 2),
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
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8A99A)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  // ==================== REJECT ====================
  // 🔥 CHANGED — also deletes `users_private` doc
  Future<void> _rejectUser(UserModel user) async {
    setState(() => _isProcessing = true);

    try {
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final data = userDoc.data() as Map<String, dynamic>;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      bool emailSent = false;
      if (hasRealEmail && storedEmail.isNotEmpty) {
        emailSent = await EmailService.sendRejectionEmail(
          storedEmail,
          user.fullName,
          _rejectionReason,
        );
      }

      // 🔥 Delete private doc first
      try {
        await _firestore.collection('users_private').doc(user.id).delete();
      } catch (e) {
        print('⚠️ Could not delete users_private: $e');
      }

      // Delete user doc
      await _firestore.collection('users').doc(user.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasRealEmail
                  ? (emailSent
                  ? '❌ ${user.fullName} rejected and notified via email'
                  : '❌ ${user.fullName} rejected but email failed')
                  : '❌ ${user.fullName} rejected (no email on file)',
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _loadPendingUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================
  // REUSABLE HEADER (inline)
  // ============================================================
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFD4C4A8),
      padding: EdgeInsets.fromLTRB(
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _iconPill(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _iconPill(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onTap: _isProcessing ? () {} : _loadPendingUsers,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.pending_actions,
                  size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pending Approvals',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 22,
                    color: Color(0xFFFFF8F0),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconPill({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFF8F0).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: const Color(0xFFFFF8F0), size: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4C4A8),
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isProcessing
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFC4A882)),
                      ),
                      SizedBox(height: 16),
                      Text('Processing...',
                          style:
                          TextStyle(color: Color(0xFF8D6E63))),
                    ],
                  ),
                )
                    : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb ? 900 : double.infinity,
                    ),
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final padding = kIsWeb ? 20.0 : 12.0;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8))),
            SizedBox(height: 16),
            Text('Loading pending approvals...',
                style: TextStyle(color: Color(0xFFB8A99A))),
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
            Text(_errorMessage!,
                style: const TextStyle(color: Color(0xFFB8A99A))),
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
            Text(
              '🎉 No pending approvals!',
              style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B5B4F),
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'All residents have been processed',
              style: TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final paginated = _paginatedUsers;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          padding, kIsWeb ? 12 : 8, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4C4A8).withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText:
                    'Search by name, ID, house, email, or phone...',
                    hintStyle: const TextStyle(
                        color: Color(0xFFB8A99A), fontSize: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFFD4C4A8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: Color(0xFFB8A99A)),
                      onPressed: _clearSearch,
                      tooltip: 'Clear',
                    )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                  ),
                ),
                const Divider(color: Color(0xFFF5F0E8), height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.pending_actions,
                        size: 14, color: Color(0xFFB8A99A)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_filteredUsers.length} pending',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB8A99A),
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Spacer(),
                    const Text('Per page:',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB8A99A),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    ..._pageSizeOptions(),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (paginated.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: const Color(0xFFE0D5C1), width: 1),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: Color(0xFFE0D5C1)),
                  SizedBox(height: 12),
                  Text(
                    'No matching pending users',
                    style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B5B4F),
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try a different search term',
                    style:
                    TextStyle(fontSize: 12, color: Color(0xFFB8A99A)),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginated.length,
              itemBuilder: (context, index) {
                return _buildPendingCard(paginated[index]);
              },
            ),

          const SizedBox(height: 12),

          if (_pageSize != 0 && total > 1)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: const Color(0xFFE0D5C1), width: 1),
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
                  IconButton(
                    icon: const Icon(Icons.first_page, size: 20),
                    onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'First page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Previous page',
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Page $_currentPage of $total',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B5B4F),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < total
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Next page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, size: 20),
                    onPressed: _currentPage < total
                        ? () => _goToPage(total)
                        : null,
                    color: const Color(0xFF8D6E63),
                    disabledColor: const Color(0xFFE0D5C1),
                    tooltip: 'Last page',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(UserModel user) {
    final hasEmail = user.email.isNotEmpty;

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
                    child: const Icon(Icons.person,
                        size: 32, color: Color(0xFFFF9800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B5B4F)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasEmail ? user.email : '📭 No email on file',
                          style: TextStyle(
                            color: hasEmail
                                ? const Color(0xFFB8A99A)
                                : const Color(0xFFFF9800),
                            fontSize: 11,
                            fontStyle: hasEmail
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (user.residentId != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFC4A882).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${user.residentId}',
                              style: const TextStyle(
                                color: Color(0xFF8D6E63),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFFF9800).withOpacity(0.3)),
                    ),
                    child: const Text(
                      '⏳ PENDING',
                      style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE0D5C1), height: 20),
              _buildInfoRow(Icons.home, '🏠 House',
                  user.houseNumber ?? 'Not provided'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.phone, '📱 Phone',
                  user.phoneNumber ?? 'Not provided'),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.calendar_today,
                '📅 Registered',
                DateFormat('MMM dd, yyyy').format(user.createdAt),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                      _isProcessing ? null : () => _approveUser(user),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _showRejectionDialog(user),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB8A99A),
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B5B4F)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _pageSizeOptions() {
    const options = <Map<String, dynamic>>[
      {'label': '10', 'value': 10},
      {'label': '20', 'value': 20},
      {'label': '50', 'value': 50},
      {'label': '100', 'value': 100},
      {'label': 'All', 'value': 0},
    ];

    return options.map((opt) {
      final value = opt['value'] as int;
      final isSelected = _pageSize == value;
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: GestureDetector(
          onTap: () => _changePageSize(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD4C4A8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD4C4A8)
                    : const Color(0xFFE0D5C1),
                width: 1,
              ),
            ),
            child: Text(
              opt['label'] as String,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFFFF8F0)
                    : const Color(0xFF8D6E63),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}