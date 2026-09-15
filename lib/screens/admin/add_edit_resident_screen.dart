// lib/screens/admin/add_edit_resident_screen.dart
import 'package:flutter/material.dart';
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
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ============================================================
  // SHOW GENERATED CREDENTIALS AFTER ADD
  // ============================================================
  Future<void> _showCredentialsDialog({
    required String residentId,
    required String password,
    required String fullName,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resident Added',
                style: TextStyle(
                  color: Color(0xFF5D4037),
                  fontWeight: FontWeight.bold,
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
                  color: const Color(0xFFFFF8F0),
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
          ),
        ),
        backgroundColor: const Color(0xFF5D4037),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFEFEBE9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                if (!_isEditing)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8D6E63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8D6E63).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline,
                            color: Color(0xFF8D6E63), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A Resident ID (FHM-###) will be auto-generated and shown after saving. '
                                'Email is optional.',
                            style: TextStyle(
                              color: Color(0xFF5D4037),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_isEditing) const SizedBox(height: 16),

                // Personal Information
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color(0xFFFFF8F0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD7CCC8),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF8D6E63),
                                      Color(0xFF5D4037),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFFFFF3E0),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Full Name (required)
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              labelStyle:
                              const TextStyle(color: Color(0xFF8D6E63)),
                              prefixIcon: const Icon(Icons.person,
                                  color: Color(0xFF8D6E63)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5D4037), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email (OPTIONAL)
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email Address (Optional)',
                              labelStyle:
                              const TextStyle(color: Color(0xFF8D6E63)),
                              prefixIcon: const Icon(Icons.email_outlined,
                                  color: Color(0xFF8D6E63)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5D4037), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              helperText: 'Leave blank if resident has no email',
                              helperStyle: const TextStyle(
                                  color: Color(0xFF8D6E63), fontSize: 11),
                            ),
                            enabled: !_isEditing,
                            keyboardType: TextInputType.emailAddress,
                            // Optional — only validates format if entered
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  !value.contains('@')) {
                                return 'Enter a valid email or leave blank';
                              }
                              return null;
                            },
                          ),

                          // Password (only when adding)
                          if (!_isEditing) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password *',
                                labelStyle: const TextStyle(
                                    color: Color(0xFF8D6E63)),
                                prefixIcon: const Icon(Icons.lock,
                                    color: Color(0xFF8D6E63)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD7CCC8)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD7CCC8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF5D4037), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                helperText:
                                'Will be shown after saving and emailed upon approval',
                                helperStyle: const TextStyle(
                                    color: Color(0xFF8D6E63), fontSize: 11),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Phone (optional)
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number (Optional)',
                              labelStyle:
                              const TextStyle(color: Color(0xFF8D6E63)),
                              prefixIcon: const Icon(Icons.phone,
                                  color: Color(0xFF8D6E63)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5D4037), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Residence Information
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color(0xFFFFF8F0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD7CCC8),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF8D6E63),
                                      Color(0xFF5D4037),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.home,
                                  color: Color(0xFFFFF3E0),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Residence Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _houseNumberController,
                            decoration: InputDecoration(
                              labelText: 'House Number / Unit *',
                              labelStyle:
                              const TextStyle(color: Color(0xFF8D6E63)),
                              prefixIcon: const Icon(Icons.home,
                                  color: Color(0xFF8D6E63)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD7CCC8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF5D4037), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'e.g., Block A, Lot 12',
                              hintStyle:
                              const TextStyle(color: Color(0xFFBCAAA4)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter house number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Action Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveResident,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: const Color(0xFFFFF3E0),
                    elevation: 5,
                    shadowColor: const Color(0xFF3E2723),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFF3E0)),
                    ),
                  )
                      : Text(_isEditing ? 'Update Resident' : 'Add Resident'),
                ),

                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8D6E63),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
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