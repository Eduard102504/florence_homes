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
  Future<void> _approveUser(UserModel user) async {
    setState(() => _isProcessing = true);

    try {
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final data = userDoc.data() as Map<String, dynamic>;

      final residentId = data['residentId'] as String?;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      String? plaintextPassword;
      try {
        final privateDoc = await _firestore.collection('users_private').doc(user.id).get();
        if (privateDoc.exists) {
          plaintextPassword = (privateDoc.data()?['plaintextPassword']) as String?;
        }
      } catch (e) {
        print('⚠️ Could not read users_private: $e');
      }

      await _firestore.collection('users').doc(user.id).update({'isApproved': true});

      bool emailSent = false;
      String message;

      if (hasRealEmail && storedEmail.isNotEmpty && residentId != null && plaintextPassword != null) {
        emailSent = await EmailService.sendResidentCredentialsEmail(
          email: storedEmail,
          fullName: user.fullName,
          residentId: residentId,
          password: plaintextPassword,
        );

        if (emailSent) {
          try {
            await _firestore.collection('users_private').doc(user.id).delete();
          } catch (e) {
            print('⚠️ Could not delete users_private: $e');
          }
        }

        message = emailSent
            ? '✅ ${user.fullName} approved. Credentials emailed.'
            : '✅ Approved but email failed. Credentials: $residentId / $plaintextPassword';
      } else if (!hasRealEmail || storedEmail.isEmpty) {
        message = '✅ ${user.fullName} approved. No email on file — credentials: $residentId / ${plaintextPassword ?? "N/A"}';
      } else {
        emailSent = await EmailService.sendApprovalEmail(storedEmail, user.fullName);
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

  // ==================== REJECT ====================
  Future<void> _showRejectionDialog(UserModel user) async {
    _rejectionReason = null;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reject Registration', style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reject ${user.fullName}\'s registration?', style: const TextStyle(color: Color(0xFF8D6E63))),
              const SizedBox(height: 16),
              const Text('Reason (optional):', style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) { _rejectionReason = value; },
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  hintStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC4A882), width: 2)),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejectUser(UserModel user) async {
    setState(() => _isProcessing = true);

    try {
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      final data = userDoc.data() as Map<String, dynamic>;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      bool emailSent = false;
      if (hasRealEmail && storedEmail.isNotEmpty) {
        emailSent = await EmailService.sendRejectionEmail(storedEmail, user.fullName, _rejectionReason);
      }

      try {
        await _firestore.collection('users_private').doc(user.id).delete();
      } catch (e) {
        print('⚠️ Could not delete users_private: $e');
      }

      await _firestore.collection('users').doc(user.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasRealEmail
                  ? (emailSent ? '❌ ${user.fullName} rejected and notified via email' : '❌ ${user.fullName} rejected but email failed')
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
          SnackBar(content: Text('Error rejecting user: $e'), backgroundColor: const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 🖥️ WEB LAYOUT
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

    // 📱 MOBILE LAYOUT
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(
              child: _buildMobileContent(screenWidth),
            ),
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
          const Text('Florence Homes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Admin Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),

          _buildWebSidebarItem(Icons.dashboard, 'Dashboard', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.people, 'Residents', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.security, 'Guards', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.pending_actions, 'Pending Approvals', isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.pop(context)),

          const Spacer(),

          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title, {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.transparent,
        leading: Icon(icon, color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title, style: TextStyle(color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8), fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pending Approvals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              _headerIconButton(icon: Icons.refresh, tooltip: 'Refresh', onTap: _isProcessing ? () {} : _loadPendingUsers, color: const Color(0xFF8D6E63)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    if (_pendingUsers.isEmpty) return const Center(child: Text('🎉 No pending approvals!', style: TextStyle(fontSize: 18, color: Color(0xFF8D6E63))));

    final paginated = _paginatedUsers;
    final total = _totalPages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1))),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(hintText: 'Search by name, ID, house, email, or phone...', border: InputBorder.none, isDense: true),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: _clearSearch),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // List
        if (paginated.isEmpty)
          const Center(child: Text('No matching pending users', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 16)))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              return _buildWebPendingRow(paginated[index]);
            },
          ),

        // Pagination
        if (_pageSize != 0 && total > 1)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null, icon: const Icon(Icons.chevron_left)),
                Text('Page $_currentPage of $total', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                IconButton(onPressed: _currentPage < total ? () => _goToPage(_currentPage + 1) : null, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWebPendingRow(UserModel user) {
    final hasEmail = user.email.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person, color: Color(0xFFFF9800), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037))),
              Text(hasEmail ? user.email : 'No email on file', style: TextStyle(fontSize: 12, color: hasEmail ? const Color(0xFF8D6E63) : const Color(0xFFFF9800))),
            ],
          )),
          Expanded(flex: 1, child: Text(user.residentId ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63), fontFamily: 'monospace'))),
          Expanded(flex: 1, child: Text(user.houseNumber ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)))),
          Expanded(flex: 1, child: Text(DateFormat('MMM dd, yyyy').format(user.createdAt), style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)))),

          // Actions
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _approveUser(user),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _showRejectionDialog(user),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap, Color color = const Color(0xFF5D4037)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.pending_actions, size: 120, color: Colors.white.withOpacity(0.05))),
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
                        child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Pending Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _isProcessing ? null : _loadPendingUsers,
                    child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, color: Color(0xFFFFF8F0), size: 20)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Review Signups', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(double screenWidth) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));

    if (_pendingUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 60, color: Color(0xFF8D6E63)),
            SizedBox(height: 16),
            Text('🎉 No pending approvals!', style: TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final paginated = _paginatedUsers;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(hintText: 'Search pending...', hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB8A99A)), border: InputBorder.none, isDense: true),
            ),
          ),
          const SizedBox(height: 16),

          // List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              return _buildMobilePendingCard(paginated[index]);
            },
          ),

          // Pagination
          if (_pageSize != 0 && total > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null, icon: const Icon(Icons.chevron_left, color: Color(0xFF8D6E63))),
                    Text('Page $_currentPage of $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                    IconButton(onPressed: _currentPage < total ? () => _goToPage(_currentPage + 1) : null, icon: const Icon(Icons.chevron_right, color: Color(0xFF8D6E63))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobilePendingCard(UserModel user) {
    final hasEmail = user.email.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person, color: Color(0xFFFF9800), size: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037))),
                      if (user.residentId != null) Text(user.residentId!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8D6E63))),
                    ],
                  ),
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFF9800).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Text('PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF9800)))),
              ],
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 24),
            _mobileInfoRow(Icons.email, 'Email', hasEmail ? user.email : 'No email on file', color: hasEmail ? const Color(0xFF5D4037) : const Color(0xFFFF9800)),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.home, 'House', user.houseNumber ?? 'Not provided'),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.phone, 'Phone', user.phoneNumber ?? 'Not provided'),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.calendar_today, 'Registered', DateFormat('MMM dd, yyyy').format(user.createdAt)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _approveUser(user),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _showRejectionDialog(user),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF5D4037), fontWeight: FontWeight.bold))),
      ],
    );
  }
}