// lib/screens/admin/manage_guards.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class ManageGuards extends StatefulWidget {
  const ManageGuards({super.key});

  @override
  State<ManageGuards> createState() => _ManageGuardsState();
}

class _ManageGuardsState extends State<ManageGuards> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<UserModel> _guards = [];
  List<UserModel> _filteredGuards = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGuards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGuards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'guard')
          .get();

      final list = snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      list.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (mounted) {
        setState(() {
          _guards = list;
          _applyFiltersInternal();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFiltersInternal() {
    if (_searchQuery.isEmpty) {
      _filteredGuards = List.from(_guards);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredGuards = _guards.where((g) {
        return g.fullName.toLowerCase().contains(q) ||
            g.email.toLowerCase().contains(q) ||
            (g.guardId?.toLowerCase().contains(q) ?? false) ||
            (g.phoneNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFiltersInternal();
    });
  }

  void _showMessage(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? const Color(0xFF8D6E63)
            : (isError ? const Color(0xFFD32F2F) : const Color(0xFFD4C4A8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== ADD GUARD ====================
  Future<void> _addGuard() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Add New Guard',
            style: TextStyle(
                color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    helperText: 'Leave blank if guard has no email',
                    helperStyle:
                    TextStyle(fontSize: 10, color: Color(0xFFB8A99A)),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Invalid email format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password *'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final res = await _authService.registerGuard(
                  fullName: nameCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isNotEmpty
                      ? emailCtrl.text.trim()
                      : null,
                );

                if (res['success']) {
                  setState(() => _isLoading = false);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Guard Added',
                          style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Give these credentials to the guard:'),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: const Color(0xFFE0D5C1))),
                            child: Column(
                              children: [
                                Text('Guard ID: ${res['guardId']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'monospace')),
                                const SizedBox(height: 8),
                                Text('Password: ${passCtrl.text.trim()}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                              'They can log in using the Guard ID and password.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close')),
                      ],
                    ),
                  );
                  _loadGuards();
                } else {
                  _showMessage(res['message'], isError: true);
                  setState(() => _isLoading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8)),
            child: const Text('Add Guard'),
          ),
        ],
      ),
    );
  }

  // ==================== DELETE GUARD ====================
  Future<void> _deleteGuard(UserModel guard) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Guard'),
        content: Text('Remove ${guard.fullName} from the system?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('users').doc(guard.id).delete();
        _showMessage('Guard deleted', isSuccess: true);
        _loadGuards();
      } catch (e) {
        _showMessage('Error: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
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
            Expanded(
              child: _buildMobileContent(),
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
          const Text('Florence Homes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8F0),
                  letterSpacing: 1)),
          const Text('Admin Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.people, 'Residents',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.security, 'Guards',
              isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.pending_actions, 'Pending Approvals',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History',
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
          const Text('Manage Guards',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
          Row(
            children: [
              _webIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onTap: _loadGuards,
                  color: const Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addGuard,
                icon: const Icon(Icons.add),
                label: const Text('Add Guard'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4C4A8),
                    foregroundColor: const Color(0xFF5D4037),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _webIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    }
    if (_errorMessage != null) {
      return Center(
          child:
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat Card
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.security,
                    size: 24, color: Color(0xFFFFF8F0)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Guards',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8D6E63),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${_guards.length}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D5C1))),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                      hintText: 'Search guard by name, ID, email, or phone...',
                      border: InputBorder.none,
                      isDense: true),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // List
        if (_filteredGuards.isEmpty)
          const Center(
              child: Text('No guards found',
                  style: TextStyle(color: Color(0xFF8D6E63), fontSize: 16)))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredGuards.length,
            itemBuilder: (context, index) =>
                _buildWebGuardRow(_filteredGuards[index]),
          ),
      ],
    );
  }

  Widget _buildWebGuardRow(UserModel guard) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.security, color: Color(0xFF5D4037)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guard.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF5D4037))),
                if (guard.email.isNotEmpty)
                  Text(guard.email,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D6E63))),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: guard.guardId != null
                ? Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFC4A882).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(guard.guardId!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFF8D6E63))),
              ),
            )
                : const Text('—',
                style: TextStyle(color: Color(0xFF8D6E63))),
          ),
          Expanded(
            flex: 1,
            child: Text(guard.phoneNumber ?? 'No phone',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF8D6E63))),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Color(0xFFD32F2F)),
            onPressed: () => _deleteGuard(guard),
            tooltip: 'Delete Guard',
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
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.security,
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
                      const Text('Manage Guards',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _addGuard,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add,
                          color: Color(0xFFFFF8F0), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Security Personnel',
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
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Color(0xFFD32F2F))));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
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
                      gradient: const LinearGradient(
                          colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.security,
                      size: 26, color: Color(0xFFFFF8F0)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Guards',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8D6E63),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('${_guards.length}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037))),
                  ],
                ),
              ],
            ),
          ),

          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D5C1))),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                  hintText: 'Search guards...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFFB8A99A)),
                  border: InputBorder.none,
                  isDense: true),
            ),
          ),
          const SizedBox(height: 16),

          // List
          if (_filteredGuards.isEmpty)
            const Center(
                child: Text('No guards found',
                    style: TextStyle(color: Color(0xFF8D6E63), fontSize: 14)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredGuards.length,
              itemBuilder: (context, index) =>
                  _buildMobileGuardCard(_filteredGuards[index]),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobileGuardCard(UserModel guard) {
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
                      color: const Color(0xFF5D4037).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child:
                  const Icon(Icons.security, color: Color(0xFF5D4037), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guard.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF5D4037))),
                      if (guard.guardId != null)
                        Text(guard.guardId!,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8D6E63))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFD32F2F), size: 22),
                  onPressed: () => _deleteGuard(guard),
                  tooltip: 'Delete Guard',
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 24),
            _mobileInfoRow(Icons.email, 'Email',
                guard.email.isEmpty ? 'No email on file' : guard.email),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.phone, 'Phone',
                guard.phoneNumber ?? 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}