// lib/screens/resident/my_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E8),
        body: Center(child: Text('Not logged in')),
      );
    }

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
                      child: _buildWebContent(authProvider),
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
              child: _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFD4C4A8)))
                  : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildContent(authProvider),
              ),
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
          const Text('Resident Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.qr_code, 'My QR Code',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.person, 'Profile',
              isActive: true, onTap: () {}),
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
          const Text('My Profile',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
        ],
      ),
    );
  }

  Widget _buildWebContent(AuthProvider authProvider) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _buildContent(authProvider),
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
              child: Icon(Icons.person,
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
                      const Text('My Profile',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Account Settings',
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

  // ============================================================
  // 🔥 SHARED CONTENT
  // ============================================================

  Widget _buildContent(AuthProvider authProvider) {
    final user = authProvider.currentUser!;
    final hasEmail = user.email.isNotEmpty;
    final hasRFID = user.rfidTag != null && user.rfidTag!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Avatar + name
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF5D4037).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFF8F0)),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.fullName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              if (user.residentId != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFC4A882).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFC4A882).withOpacity(0.3))),
                  child: Text(user.residentId!,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF8D6E63),
                          letterSpacing: 1)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Info card
        _buildInfoCard(
          title: 'Account Information',
          children: [
            _buildInfoRow(Icons.badge, 'Resident ID',
                user.residentId ?? 'Not assigned'),
            _buildInfoRow(Icons.person, 'Full Name', user.fullName),
            _buildInfoRow(
                Icons.email, 'Email',
                hasEmail ? user.email : 'No email on file',
                highlight: !hasEmail),
            _buildInfoRow(Icons.phone, 'Phone',
                user.phoneNumber ?? 'Not provided'),
            _buildInfoRow(
                Icons.home, 'House', user.houseNumber ?? 'Not assigned'),
            _buildInfoRow(Icons.nfc, 'RFID',
                hasRFID ? 'Registered' : 'Not registered'),
            _buildInfoRow(
                Icons.verified,
                'Status',
                user.isApproved ? 'Approved' : 'Pending Approval'),
          ],
        ),
        const SizedBox(height: 16),

        // Add email
        if (!hasEmail) ...[
          _buildActionCard(
            icon: Icons.email_outlined,
            title: 'Add Email Address',
            subtitle: 'Add an email to enable password changes and recovery',
            buttonLabel: 'Add Email',
            buttonColor: const Color(0xFF5D4037),
            onPressed: () => _showAddEmailDialog(context, authProvider),
          ),
          const SizedBox(height: 12),
        ],

        // Change password
        _buildActionCard(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: hasEmail
              ? 'We\'ll send a verification code to ${user.email}'
              : 'Add an email first to enable password changes',
          buttonLabel: 'Change Password',
          buttonColor:
          hasEmail ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A),
          enabled: hasEmail,
          onPressed: hasEmail
              ? () => _showChangePasswordDialog(context, authProvider)
              : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==================== ADD EMAIL DIALOG ====================
  Future<void> _showAddEmailDialog(
      BuildContext context, AuthProvider authProvider) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.email_outlined, color: Color(0xFF8D6E63), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Add Email Address',
                    style: TextStyle(
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'We need to verify it\'s you. Please enter your current password.',
                      style:
                      TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dialogInputDecoration(
                        'New Email Address', Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: _dialogInputDecoration(
                        'Current Password', Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFF8D6E63)),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8A99A)),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Email'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final result = await _authService.addEmailToAccount(
      userId: authProvider.currentUser!.id!,
      currentPassword: passwordCtrl.text,
      newEmail: emailCtrl.text,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      await authProvider.reloadCurrentUser();
      _showSnack('✅ Email added successfully', isSuccess: true);
    } else {
      _showSnack('❌ ${result['message']}', isError: true);
    }
  }

  // ==================== CHANGE PASSWORD DIALOG ====================
  Future<void> _showChangePasswordDialog(
      BuildContext context, AuthProvider authProvider) async {
    final user = authProvider.currentUser!;
    final codeCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool codeSent = false;
    bool obscure1 = true;
    bool obscure2 = true;
    bool sendingCode = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF8F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: Color(0xFF8D6E63), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Change Password',
                    style: TextStyle(
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!codeSent) ...[
                    const Text(
                        'We\'ll send a 6-digit verification code to your email to confirm this change.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF8D6E63))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFC4A882).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFC4A882).withOpacity(0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.email,
                              size: 18, color: Color(0xFF8D6E63)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(user.email,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5D4037),
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'),
                      decoration: _dialogInputDecoration(
                          'Verification Code', Icons.pin_outlined)
                          .copyWith(counterText: ''),
                      validator: (v) {
                        if (v == null || v.length != 6) {
                          return 'Enter the 6-digit code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscure1,
                      decoration:
                      _dialogInputDecoration('New Password', Icons.lock)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8D6E63)),
                          onPressed: () =>
                              setDialogState(() => obscure1 = !obscure1),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Min 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure2,
                      decoration: _dialogInputDecoration(
                          'Confirm New Password', Icons.lock)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8D6E63)),
                          onPressed: () =>
                              setDialogState(() => obscure2 = !obscure2),
                        ),
                      ),
                      validator: (v) {
                        if (v != passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8A99A)),
              child: const Text('Cancel'),
            ),
            if (!codeSent)
              ElevatedButton(
                onPressed: sendingCode
                    ? null
                    : () async {
                  setDialogState(() => sendingCode = true);
                  final result =
                  await _authService.sendPasswordChangeCode(user.id!);
                  setDialogState(() => sendingCode = false);

                  if (!mounted) return;
                  if (result['success'] == true) {
                    setDialogState(() => codeSent = true);
                    _showSnack('📩 Code sent to ${user.email}',
                        isSuccess: true);
                  } else {
                    _showSnack('❌ ${result['message']}', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: sendingCode
                    ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFF8F0))))
                    : const Text('Send Code'),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final result = await _authService.changePasswordWithCode(
                    userId: user.id!,
                    email: user.email,
                    code: codeCtrl.text.trim(),
                    newPassword: passwordCtrl.text,
                  );

                  if (!mounted) return;
                  if (result['success'] == true) {
                    Navigator.pop(ctx);
                    _showSnack('✅ Password changed successfully',
                        isSuccess: true);
                  } else {
                    _showSnack('❌ ${result['message']}', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Change Password'),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8D6E63)),
      labelStyle: const TextStyle(color: Color(0xFF8D6E63)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // ==================== UI HELPERS ====================
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: const Color(0xFF5D4037)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8D6E63),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        color: highlight
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF5D4037),
                        fontWeight: FontWeight.w600,
                        fontStyle:
                        highlight ? FontStyle.italic : FontStyle.normal),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5)),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFF5D4037).withOpacity(0.1)
                      : const Color(0xFFB8A99A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,
                  size: 22,
                  color: enabled
                      ? const Color(0xFF5D4037)
                      : const Color(0xFFB8A99A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: enabled
                              ? const Color(0xFF5D4037)
                              : const Color(0xFFB8A99A))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8D6E63))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor:
                  enabled ? Colors.white : const Color(0xFF5D4037),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0),
              child: Text(buttonLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? const Color(0xFF4CAF50)
            : (isError ? const Color(0xFFD32F2F) : const Color(0xFF8D6E63)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}