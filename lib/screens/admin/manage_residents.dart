import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../services/tcp_service.dart';
import '../../services/archive_service.dart';
import '../../models/user_model.dart';
import 'archived_residents_screen.dart';
import 'resident_records_screen.dart';

class ManageResidents extends StatefulWidget {
  const ManageResidents({super.key});

  @override
  State<ManageResidents> createState() => _ManageResidentsState();
}

class _ManageResidentsState extends State<ManageResidents> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TCPService _tcpService = TCPService();
  final ArchiveService _archiveService = ArchiveService();

  List<UserModel> _residents = [];
  List<UserModel> _filteredResidents = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _connectToPi();
  }

  Future<void> _connectToPi() async {
    await _tcpService.connect();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== LOAD ====================
  Future<void> _loadResidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .get();

      final list = snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      list.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (mounted) {
        setState(() {
          _residents = list;
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

  // ==================== SEARCH + PAGINATION HELPERS ====================
  void _applyFiltersInternal() {
    if (_searchQuery.isEmpty) {
      _filteredResidents = List.from(_residents);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredResidents = _residents.where((r) {
        return r.fullName.toLowerCase().contains(q) ||
            (r.houseNumber?.toLowerCase().contains(q) ?? false) ||
            r.email.toLowerCase().contains(q) ||
            (r.residentId?.toLowerCase().contains(q) ?? false) ||
            (r.rfidTag?.toLowerCase().contains(q) ?? false);
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
    if (_filteredResidents.isEmpty) return 1;
    return ((_filteredResidents.length - 1) ~/ _pageSize) + 1;
  }

  List<UserModel> get _paginatedResidents {
    if (_pageSize == 0) return _filteredResidents;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _filteredResidents.length) return [];
    final end = (start + _pageSize).clamp(0, _filteredResidents.length);
    return _filteredResidents.sublist(start, end);
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

  // ==================== RFID REGISTRATION ====================
  Future<void> _registerRFID(UserModel resident) async {
    if (!_tcpService.isConnected) {
      _showMessage('Not connected to RFID scanner', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Register RFID', style: TextStyle(color: Color(0xFF6B5B4F))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 80, color: Color(0xFFD4C4A8)),
            const SizedBox(height: 16),
            const Text('Please tap RFID tag for:', style: TextStyle(color: Color(0xFF8D6E63))),
            const SizedBox(height: 8),
            Text(resident.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5D4037))),
            const SizedBox(height: 24),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8))),
            const SizedBox(height: 16),
            const Text('Waiting for tag...', style: TextStyle(fontSize: 12, color: Color(0xFFB8A99A))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _tcpService.sendCommand("CANCEL_REGISTRATION");
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    String response = await _tcpService.sendCommand("REGISTER:${resident.id}:${resident.fullName}");

    if (response == "WAITING_FOR_TAG") {
      bool registered = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        DocumentSnapshot updatedDoc = await _firestore.collection('users').doc(resident.id).get();
        String? rfidTag = updatedDoc.get('rfidTag');
        if (rfidTag != null && rfidTag.isNotEmpty) {
          registered = true;
          break;
        }
      }

      if (mounted) {
        Navigator.pop(context);
        if (registered) {
          _showMessage('✅ RFID registered for ${resident.fullName}', isSuccess: true);
          _loadResidents();
        } else {
          _showMessage('❌ Registration timeout. Please try again.', isError: true);
        }
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        _showMessage('❌ Registration failed: $response', isError: true);
      }
    }
  }

  Future<void> _removeRFID(UserModel resident) async {
    if (resident.rfidTag == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove RFID', style: TextStyle(color: Color(0xFF6B5B4F))),
        content: Text('Remove RFID tag from ${resident.fullName}?', style: const TextStyle(color: Color(0xFF8D6E63))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('rfid_tags').doc(resident.rfidTag).delete();
        await _firestore.collection('users').doc(resident.id).update({'rfidTag': FieldValue.delete()});
        _showMessage('RFID removed from ${resident.fullName}', isSuccess: true);
        _loadResidents();
      } catch (e) {
        _showMessage('Error: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF8D6E63) : (isError ? const Color(0xFFD32F2F) : const Color(0xFFD4C4A8)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== ADD / EDIT RESIDENT ====================
  Future<void> _addEditResident({UserModel? resident}) async {
    final isEditing = resident != null;
    final nameController = TextEditingController(text: resident?.fullName ?? '');
    final emailController = TextEditingController(text: resident?.email ?? '');
    final houseController = TextEditingController(text: resident?.houseNumber ?? '');
    final phoneController = TextEditingController(text: resident?.phoneNumber ?? '');
    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? '✏️ Edit Resident' : '➕ Add New Resident',
          style: const TextStyle(color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '👤 Full Name *',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '📧 Email (Optional)',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      helperText: 'Leave blank if resident has no email',
                      helperStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && !v.contains('@')) return 'Enter a valid email or leave blank';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: '🏠 House Number *',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '📱 Phone Number (Optional)',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '🔒 Password *',
                        labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                        helperText: 'Shown after saving & emailed upon approval',
                        helperStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFF8D6E63)),
                          SizedBox(width: 8),
                          Expanded(child: Text('An FHM-### Resident ID will be auto-generated after saving.', style: TextStyle(fontSize: 11, color: Color(0xFF6B5B4F)))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);

              if (isEditing) {
                await _firestore.collection('users').doc(resident.id).update({
                  'fullName': nameController.text.trim(),
                  'email': emailController.text.trim().toLowerCase(),
                  'houseNumber': houseController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                  if (emailController.text.trim().isNotEmpty) 'hasRealEmail': true,
                });
                _showMessage('Resident updated', isSuccess: true);
                _loadResidents();
              } else {
                final result = await _authService.registerResidentManually(
                  fullName: nameController.text.trim(),
                  password: passwordController.text.trim(),
                  houseNumber: houseController.text.trim(),
                  email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                  phoneNumber: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                );

                if (result['success'] == true) {
                  if (mounted) {
                    await _showCredentialsDialog(
                      residentId: result['residentId'] as String,
                      password: result['password'] as String,
                      fullName: nameController.text.trim(),
                      emailProvided: emailController.text.trim().isNotEmpty,
                    );
                  }
                  _loadResidents();
                } else {
                  _showMessage(result['message'] ?? 'Failed to add resident', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4C4A8), foregroundColor: const Color(0xFF6B5B4F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCredentialsDialog({required String residentId, required String password, required String fullName, required bool emailProvided}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 26),
            SizedBox(width: 10),
            Expanded(child: Text('Resident Added', style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$fullName has been added and is pending approval.', style: const TextStyle(color: Color(0xFF6B5B4F), fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD4C4A8), width: 1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LOGIN CREDENTIALS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF8D6E63))),
                    const SizedBox(height: 12),
                    _credRow('Resident ID', residentId, highlight: true),
                    const SizedBox(height: 8),
                    _credRow('Password', password),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emailProvided ? '⚠️ These credentials will be emailed to the resident upon approval.' : '⚠️ No email provided. Give these credentials to the resident manually after approval.',
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: const Color(0xFF8D6E63)), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: highlight ? 16 : 14, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: highlight ? const Color(0xFFC4A882) : const Color(0xFF5D4037)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // ==================== DELETE / ARCHIVE RESIDENT ====================
  Future<void> _deleteResident(UserModel resident) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.archive_outlined, color: Color(0xFF8D6E63), size: 24),
            SizedBox(width: 8),
            Text('Archive Resident', style: TextStyle(color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to archive ${resident.fullName}?', style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13)),
            const SizedBox(height: 8),
            const Text('The resident will be moved to the archive and can be restored later.', style: TextStyle(color: Color(0xFFB8A99A), fontSize: 11, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive, size: 16),
            label: const Text('Archive'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await _firestore.collection('users').doc(resident.id).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final adminAuth = _authService.getCurrentUserId();
      String adminName = 'Administrator';
      if (adminAuth != null) {
        final adminDoc = await _firestore.collection('users').doc(adminAuth).get();
        adminName = (adminDoc.get('fullName') as String?) ?? 'Administrator';
      }

      final archived = await _archiveService.archiveResident(
        userData: userData,
        originalId: resident.id!,
        adminUid: adminAuth,
        adminName: adminName,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );

      if (!archived) {
        _showMessage('Failed to archive resident', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      if (resident.rfidTag != null) {
        await _firestore.collection('rfid_tags').doc(resident.rfidTag).delete();
      }

      await _firestore.collection('users').doc(resident.id).delete();
      _showMessage('${resident.fullName} archived successfully', isSuccess: true);
      _loadResidents();
    } catch (e) {
      _showMessage('Error archiving resident: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // ==================== APPROVE RESIDENT ====================
  Future<void> _approveResident(UserModel resident) async {
    if (resident.isApproved) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await _firestore.collection('users').doc(resident.id).get();
      final data = userDoc.data() as Map<String, dynamic>;

      final residentId = data['residentId'] as String?;
      final plaintextPassword = data['plaintextPassword'] as String?;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      await _firestore.collection('users').doc(resident.id).update({'isApproved': true});

      bool emailSent = false;
      String message;

      if (hasRealEmail && storedEmail.isNotEmpty && residentId != null && plaintextPassword != null) {
        emailSent = await EmailService.sendResidentCredentialsEmail(
          email: storedEmail,
          fullName: resident.fullName,
          residentId: residentId,
          password: plaintextPassword,
        );

        if (emailSent) {
          await _firestore.collection('users').doc(resident.id).update({'plaintextPassword': FieldValue.delete()});
        }

        message = emailSent
            ? '✅ ${resident.fullName} approved. Credentials emailed.'
            : '✅ Approved but email failed. Credentials: $residentId / $plaintextPassword';
      } else if (!hasRealEmail || storedEmail.isEmpty) {
        message = '✅ ${resident.fullName} approved. No email on file — credentials: $residentId / ${plaintextPassword ?? "N/A"}';
      } else {
        emailSent = await EmailService.sendApprovalEmail(storedEmail, resident.fullName);
        message = emailSent
            ? '✅ ${resident.fullName} approved and notified via email.'
            : '✅ ${resident.fullName} approved but email failed.';
      }

      _showMessage(message, isSuccess: true);
      _loadResidents();
    } catch (e) {
      _showMessage('Error: $e', isError: true);
      setState(() => _isLoading = false);
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
          _buildWebSidebarItem(Icons.people, 'Residents', isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.security, 'Guards', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.pending_actions, 'Pending Approvals', onTap: () => Navigator.pop(context)),
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
          const Text('Manage Residents', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              _webIconButton(icon: Icons.archive_outlined, tooltip: 'Archive', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedResidentsScreen())), color: const Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              _webIconButton(icon: Icons.library_books_outlined, tooltip: 'Records', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResidentRecordsScreen())), color: const Color(0xFF8D6E63)),
              const SizedBox(width: 12),
              _webIconButton(icon: Icons.refresh, tooltip: 'Refresh', onTap: _loadResidents, color: const Color(0xFF8D6E63)),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: () => _addEditResident(),
                icon: const Icon(Icons.add),
                label: const Text('Add Resident'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4C4A8), foregroundColor: const Color(0xFF5D4037), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _webIconButton({required IconData icon, required String tooltip, required VoidCallback onTap, required Color color}) {
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

  Widget _buildWebContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));

    final paginated = _paginatedResidents;
    final total = _totalPages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat Cards
        Row(
          children: [
            _buildWebStatCard('Total Residents', _filteredResidents.length.toString(), Icons.people, const Color(0xFF8D6E63)),
            const SizedBox(width: 20),
            _buildWebStatCard('Approved', _filteredResidents.where((r) => r.isApproved).length.toString(), Icons.check_circle, const Color(0xFF4CAF50)),
            const SizedBox(width: 20),
            _buildWebStatCard('RFID Registered', _filteredResidents.where((r) => r.rfidTag != null).length.toString(), Icons.nfc, const Color(0xFFC4A882)),
          ],
        ),
        const SizedBox(height: 24),

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
                  decoration: const InputDecoration(hintText: 'Search by name, ID, house, email, or RFID tag...', border: InputBorder.none, isDense: true),
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
          const Center(child: Text('No residents found', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 16)))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final globalIndex = _pageSize == 0 ? index + 1 : ((_currentPage - 1) * _pageSize) + index + 1;
              return _buildWebResidentRow(paginated[index], globalIndex);
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

  Widget _buildWebStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebResidentRow(UserModel resident, int index) {
    final hasRFID = resident.rfidTag != null && resident.rfidTag!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Text('#$index', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFB8A99A))),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Text(resident.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037)))),
          Expanded(flex: 1, child: Text(resident.residentId ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63), fontFamily: 'monospace'))),
          Expanded(flex: 1, child: Text(resident.houseNumber ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF8D6E63)))),
          Expanded(flex: 1, child: Text(hasRFID ? 'Yes' : 'No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: hasRFID ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)))),
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: resident.isApproved ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(resident.isApproved ? 'Approved' : 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: resident.isApproved ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF8D6E63)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Info')),
              if (!resident.isApproved) const PopupMenuItem(value: 'approve', child: Text('Approve')),
              if (!hasRFID) const PopupMenuItem(value: 'register_rfid', child: Text('Add RFID')),
              if (hasRFID) const PopupMenuItem(value: 'remove_rfid', child: Text('Remove RFID')),
              const PopupMenuItem(value: 'delete', child: Text('Archive', style: TextStyle(color: Color(0xFFD32F2F)))),
            ],
            onSelected: (value) async {
              if (value == 'edit') await _addEditResident(resident: resident);
              if (value == 'approve') await _approveResident(resident);
              if (value == 'register_rfid') await _registerRFID(resident);
              if (value == 'remove_rfid') await _removeRFID(resident);
              if (value == 'delete') await _deleteResident(resident);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS (MATCHING NEW DESIGN)
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
          Positioned(right: -20, top: -20, child: Icon(Icons.people, size: 120, color: Colors.white.withOpacity(0.05))),
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
                      const Text('Manage Residents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _addEditResident(),
                    child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Color(0xFFFFF8F0), size: 20)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Resident Directory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent(double screenWidth) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));

    final paginated = _paginatedResidents;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards (One Line)
          Row(
            children: [
              _mobileStatCard('Total', _filteredResidents.length.toString(), Icons.people, const Color(0xFF5D4037)),
              const SizedBox(width: 8),
              _mobileStatCard('Approved', _filteredResidents.where((r) => r.isApproved).length.toString(), Icons.check_circle, const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              _mobileStatCard('RFID', _filteredResidents.where((r) => r.rfidTag != null).length.toString(), Icons.nfc, const Color(0xFF8D6E63)),
            ],
          ),
          const SizedBox(height: 20),

          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(hintText: 'Search residents...', hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB8A99A)), border: InputBorder.none, isDense: true),
            ),
          ),
          const SizedBox(height: 16),

          // List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final globalIndex = _pageSize == 0 ? index + 1 : ((_currentPage - 1) * _pageSize) + index + 1;
              return _buildMobileResidentCard(paginated[index], globalIndex);
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

  Widget _mobileStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileResidentCard(UserModel resident, int index) {
    final hasRFID = resident.rfidTag != null && resident.rfidTag!.isNotEmpty;

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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: resident.isApproved ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFFFF9800).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person, color: resident.isApproved ? const Color(0xFF4CAF50) : const Color(0xFFFF9800), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resident.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF5D4037))),
                      if (resident.residentId != null)
                        Text(resident.residentId!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8D6E63))),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF8D6E63)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Info')),
                    if (!resident.isApproved) const PopupMenuItem(value: 'approve', child: Text('Approve')),
                    if (!hasRFID) const PopupMenuItem(value: 'register_rfid', child: Text('Add RFID')),
                    if (hasRFID) const PopupMenuItem(value: 'remove_rfid', child: Text('Remove RFID')),
                    const PopupMenuItem(value: 'delete', child: Text('Archive', style: TextStyle(color: Color(0xFFD32F2F)))),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') await _addEditResident(resident: resident);
                    if (value == 'approve') await _approveResident(resident);
                    if (value == 'register_rfid') await _registerRFID(resident);
                    if (value == 'remove_rfid') await _removeRFID(resident);
                    if (value == 'delete') await _deleteResident(resident);
                  },
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 24),
            _mobileInfoRow(Icons.home, 'House', resident.houseNumber ?? 'Not assigned'),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.email, 'Email', resident.email.isEmpty ? 'Not provided' : resident.email),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.phone, 'Phone', resident.phoneNumber ?? 'Not provided'),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.nfc, 'RFID', hasRFID ? 'Registered' : 'No tag'),
            const SizedBox(height: 6),
            _mobileInfoRow(Icons.verified, 'Status', resident.isApproved ? 'Approved' : 'Pending Approval', color: resident.isApproved ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)),
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
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ==================== SHARED HELPERS ====================
  Widget _pageSizeOptionsHelper() {
    const options = <Map<String, dynamic>>[
      {'label': '10', 'value': 10},
      {'label': '20', 'value': 20},
      {'label': '50', 'value': 50},
      {'label': '100', 'value': 100},
      {'label': 'All', 'value': 0},
    ];

    return Wrap(
      spacing: 4,
      children: options.map((opt) {
        final value = opt['value'] as int;
        final isSelected = _pageSize == value;
        return GestureDetector(
          onTap: () => _changePageSize(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD4C4A8) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFFD4C4A8) : const Color(0xFFE0D5C1), width: 1),
            ),
            child: Text(
              opt['label'] as String,
              style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF8D6E63)),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _shortTag(String tag) {
    if (tag.length <= 10) return tag;
    return '${tag.substring(0, 6)}…${tag.substring(tag.length - 3)}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}