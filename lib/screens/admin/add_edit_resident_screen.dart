// lib/screens/admin/add_edit_resident_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class AddEditResidentScreen extends StatefulWidget {
  final UserModel? resident;

  const AddEditResidentScreen({super.key, this.resident});

  @override
  State<AddEditResidentScreen> createState() => _AddEditResidentScreenState();
}

class _AddEditResidentScreenState extends State<AddEditResidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isEditing = false;

  final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
  final double outerPadding = kIsWeb ? 20 : 16;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.resident != null;

    if (widget.resident != null) {
      _nameController.text = widget.resident!.fullName;
      _emailController.text = widget.resident!.email;
      _phoneController.text = widget.resident!.phoneNumber ?? '';
      _houseNumberController.text = widget.resident!.houseNumber ?? '';
    }
  }

  Future<void> _saveResident() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await _firestore.collection('users').doc(widget.resident!.id).update({
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'houseNumber': _houseNumberController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim().toLowerCase(),
          if (_emailController.text.trim().isNotEmpty)
            'hasRealEmail': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resident updated successfully'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final result = await _authService.registerResidentManually(
          fullName: _nameController.text.trim(),
          password: _passwordController.text.trim(),
          houseNumber: _houseNumberController.text.trim(),
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

        if (result['success']) {
          if (mounted) {
            await _showCredentialsDialog(
              residentId: result['residentId'] as String,
              password: result['password'] as String,
              fullName: _nameController.text.trim(),
            );
            if (mounted) Navigator.pop(context, true);
          }
        } else {
          throw Exception(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showCredentialsDialog({
    required String residentId,
    required String password,
    required String fullName,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resident Added',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$fullName has been added and is pending approval.',
                style:
                const TextStyle(color: Color(0xFF6B5B4F), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: const Color(0xFFD4C4A8), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOGIN CREDENTIALS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _credRow('Resident ID', residentId, highlight: true),
                    const SizedBox(height: 8),
                    _credRow('Password', password),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠️ Save these credentials. They will be emailed to the resident upon approval (if an email was provided).',
                style: TextStyle(
                  color: Color(0xFF8D6E63),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8D6E63),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8D6E63),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 16 : 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: highlight
                  ? const Color(0xFFC4A882)
                  : const Color(0xFF5D4037),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Resident' : 'Add New Resident',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
      ),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.all(outerPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ============ INFO BANNER ============
                      if (!_isEditing)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4C4A8)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD4C4A8)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF8D6E63), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'A Resident ID (FHM-###) will be auto-generated after saving.',
                                  style: TextStyle(
                                    color: Color(0xFF5D4037),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_isEditing) const SizedBox(height: 14),

                      // ============ PERSONAL INFO ============
                      _buildCard(
                        title: 'Personal Information',
                        icon: Icons.person,
                        children: [
                          _buildField(
                            controller: _nameController,
                            label: 'Full Name *',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _emailController,
                            label: 'Email Address (Optional)',
                            icon: Icons.email_outlined,
                            hint: 'Leave blank if resident has no email',
                            enabled: !_isEditing,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v != null &&
                                  v.trim().isNotEmpty &&
                                  !v.contains('@')) {
                                return 'Enter a valid email or leave blank';
                              }
                              return null;
                            },
                          ),
                          if (!_isEditing) ...[
                            const SizedBox(height: 12),
                            _buildField(
                              controller: _passwordController,
                              label: 'Password *',
                              icon: Icons.lock_outline,
                              hint:
                              'Will be emailed upon approval',
                              obscure: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _phoneController,
                            label: 'Phone Number (Optional)',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ============ RESIDENCE INFO ============
                      _buildCard(
                        title: 'Residence Information',
                        icon: Icons.home,
                        children: [
                          _buildField(
                            controller: _houseNumberController,
                            label: 'House Number / Unit *',
                            icon: Icons.home_outlined,
                            hint: 'e.g., Block A, Lot 12',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ============ ACTION ============
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveResident,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: const Color(0xFFD4C4A8),
                          foregroundColor: const Color(0xFF6B5B4F),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Color(0xFF6B5B4F)),
                          ),
                        )
                            : Text(_isEditing
                            ? 'Update Resident'
                            : 'Add Resident'),
                      ),

                      if (_isEditing) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8D6E63),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============ CARD WRAPPER ============
  Widget _buildCard({
    required String title,
    required IconData icon,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4C4A8).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                  Icon(icon, color: const Color(0xFF8D6E63), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B5B4F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // ============ INPUT FIELD ============
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool enabled = true,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
        const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
        hintStyle:
        const TextStyle(color: Color(0xFFD4C4A8), fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFFD4C4A8), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFFD4C4A8), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFFFF8F0),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}