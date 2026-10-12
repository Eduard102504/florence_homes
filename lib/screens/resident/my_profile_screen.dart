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

  final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
  final double outerPadding = kIsWeb ? 24 : 16;

  // ============================================================
  // INLINE HEADER
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.person, size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'My Profile',
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4C4A8),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(child: Text('Not logged in')),
              ),
            ],
          ),
        ),
      );
    }

    final hasEmail = user.email.isNotEmpty;
    final hasRFID = user.rfidTag != null && user.rfidTag!.isNotEmpty;

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
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFD4C4A8)),
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
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          // ==================== AVATAR + NAME ====================
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                      kIsWeb ? 16 : 20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFD4C4A8),
                                        Color(0xFFC4A882),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                            0xFFD4C4A8)
                                            .withOpacity(0.3),
                                        blurRadius: 15,
                                        offset:
                                        const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    user.fullName.isNotEmpty
                                        ? user.fullName[0]
                                        .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 34 : 42,
                                      fontWeight: FontWeight.bold,
                                      color:
                                      const Color(0xFFFFF8F0),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    height: kIsWeb ? 10 : 12),
                                Text(
                                  user.fullName,
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color:
                                    const Color(0xFF5D4037),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (user.residentId != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC4A882)
                                          .withOpacity(0.15),
                                      borderRadius:
                                      BorderRadius.circular(
                                          20),
                                      border: Border.all(
                                        color: const Color(
                                            0xFFC4A882)
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      user.residentId!,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF8D6E63),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: kIsWeb ? 18 : 24),

                          // ==================== INFO CARD ====================
                          _buildInfoCard(
                            title: 'Account Information',
                            children: [
                              _buildInfoRow(
                                  Icons.badge,
                                  'Resident ID',
                                  user.residentId ??
                                      'Not assigned'),
                              _buildInfoRow(Icons.person, 'Full Name',
                                  user.fullName),
                              _buildInfoRow(
                                Icons.email,
                                'Email',
                                hasEmail
                                    ? user.email
                                    : 'No email on file',
                                highlight: !hasEmail,
                              ),
                              _buildInfoRow(
                                  Icons.phone,
                                  'Phone',
                                  user.phoneNumber ??
                                      'Not provided'),
                              _buildInfoRow(
                                  Icons.home,
                                  'House',
                                  user.houseNumber ??
                                      'Not assigned'),
                              _buildInfoRow(
                                  Icons.nfc,
                                  'RFID',
                                  hasRFID
                                      ? 'Registered'
                                      : 'Not registered'),
                              _buildInfoRow(
                                Icons.verified,
                                'Status',
                                user.isApproved
                                    ? 'Approved'
                                    : 'Pending Approval',
                              ),
                            ],
                          ),
                          SizedBox(height: kIsWeb ? 14 : 16),

                          // ==================== ADD EMAIL ====================
                          if (!hasEmail) ...[
                            _buildActionCard(
                              icon: Icons.email_outlined,
                              title: 'Add Email Address',
                              subtitle:
                              'Add an email to enable password changes and recovery',
                              buttonLabel: 'Add Email',
                              buttonColor:
                              const Color(0xFFD4C4A8),
                              onPressed: () => _showAddEmailDialog(
                                  context, authProvider),
                            ),
                            SizedBox(height: kIsWeb ? 10 : 12),
                          ],

                          // ==================== CHANGE PASSWORD ====================
                          _buildActionCard(
                            icon: Icons.lock_outline,
                            title: 'Change Password',
                            subtitle: hasEmail
                                ? 'We\'ll send a verification code to ${user.email}'
                                : 'Add an email first to enable password changes',
                            buttonLabel: 'Change Password',
                            buttonColor: hasEmail
                                ? const Color(0xFF8D6E63)
                                : const Color(0xFFB8A99A),
                            enabled: hasEmail,
                            onPressed: hasEmail
                                ? () => _showChangePasswordDialog(
                                context, authProvider)
                                : null,
                          ),

                          SizedBox(height: kIsWeb ? 20 : 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              Icon(Icons.email_outlined,
                  color: Color(0xFF8D6E63), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add Email Address',
                  style: TextStyle(
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
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
                    TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'New Email Address',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF8D6E63)),
                      labelStyle:
                      const TextStyle(color: Color(0xFF8D6E63)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF8D6E63)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFF8D6E63),
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      labelStyle:
                      const TextStyle(color: Color(0xFF8D6E63)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
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
              Icon(Icons.lock_outline,
                  color: Color(0xFF8D6E63), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Change Password',
                  style: TextStyle(
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
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
                          fontSize: 12, color: Color(0xFF8D6E63)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFFC4A882).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFC4A882)
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email,
                              size: 18, color: Color(0xFF8D6E63)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.email,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B5B4F),
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
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
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        counterText: '',
                        labelStyle:
                        const TextStyle(color: Color(0xFF8D6E63)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFD4C4A8), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
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
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock,
                            color: Color(0xFF8D6E63)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8D6E63)),
                          onPressed: () => setDialogState(
                                  () => obscure1 = !obscure1),
                        ),
                        labelStyle:
                        const TextStyle(color: Color(0xFF8D6E63)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFD4C4A8), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock,
                            color: Color(0xFF8D6E63)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8D6E63)),
                          onPressed: () => setDialogState(
                                  () => obscure2 = !obscure2),
                        ),
                        labelStyle:
                        const TextStyle(color: Color(0xFF8D6E63)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFD4C4A8), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                  final result = await _authService
                      .sendPasswordChangeCode(user.id!);
                  setDialogState(() => sendingCode = false);

                  if (!mounted) return;
                  if (result['success'] == true) {
                    setDialogState(() => codeSent = true);
                    _showSnack('📩 Code sent to ${user.email}',
                        isSuccess: true);
                  } else {
                    _showSnack('❌ ${result['message']}',
                        isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4C4A8),
                  foregroundColor: const Color(0xFF6B5B4F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: sendingCode
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B5B4F))),
                )
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Change Password'),
              ),
          ],
        ),
      ),
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
        ),
        padding: EdgeInsets.all(kIsWeb ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: kIsWeb ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8D6E63),
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: kIsWeb ? 10 : 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: kIsWeb ? 6 : 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(kIsWeb ? 6 : 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4C4A8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: kIsWeb ? 14 : 16, color: const Color(0xFF8D6E63)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: kIsWeb ? 10 : 11,
                    color: const Color(0xFFB8A99A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: kIsWeb ? 12 : 13,
                    color: highlight
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                    fontStyle:
                    highlight ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
        ),
        padding: EdgeInsets.all(kIsWeb ? 14 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(kIsWeb ? 8 : 10),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFD4C4A8).withOpacity(0.2)
                    : const Color(0xFFB8A99A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: kIsWeb ? 18 : 22,
                  color: enabled
                      ? const Color(0xFF8D6E63)
                      : const Color(0xFFB8A99A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: kIsWeb ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: enabled
                          ? const Color(0xFF5D4037)
                          : const Color(0xFFB8A99A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFB8A99A)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: enabled
                    ? Colors.white
                    : const Color(0xFF6B5B4F),
                padding: EdgeInsets.symmetric(
                    horizontal: kIsWeb ? 12 : 14,
                    vertical: kIsWeb ? 8 : 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                buttonLabel,
                style: TextStyle(
                    fontSize: kIsWeb ? 11 : 12,
                    fontWeight: FontWeight.bold),
              ),
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