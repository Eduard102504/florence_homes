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
        title: const Text('Register RFID',
            style: TextStyle(color: Color(0xFF6B5B4F))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 80, color: Color(0xFFD4C4A8)),
            const SizedBox(height: 16),
            const Text('Please tap RFID tag for:',
                style: TextStyle(color: Color(0xFF8D6E63))),
            const SizedBox(height: 8),
            Text(resident.fullName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF5D4037))),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8))),
            const SizedBox(height: 16),
            const Text('Waiting for tag...',
                style: TextStyle(fontSize: 12, color: Color(0xFFB8A99A))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _tcpService.sendCommand("CANCEL_REGISTRATION");
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    String response = await _tcpService
        .sendCommand("REGISTER:${resident.id}:${resident.fullName}");

    if (response == "WAITING_FOR_TAG") {
      bool registered = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));

        DocumentSnapshot updatedDoc =
        await _firestore.collection('users').doc(resident.id).get();

        String? rfidTag = updatedDoc.get('rfidTag');
        if (rfidTag != null && rfidTag.isNotEmpty) {
          registered = true;
          break;
        }
      }

      if (mounted) {
        Navigator.pop(context);

        if (registered) {
          _showMessage('✅ RFID registered for ${resident.fullName}',
              isSuccess: true);
          _loadResidents();
        } else {
          _showMessage('❌ Registration timeout. Please try again.',
              isError: true);
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
        title: const Text('Remove RFID',
            style: TextStyle(color: Color(0xFF6B5B4F))),
        content: Text('Remove RFID tag from ${resident.fullName}?',
            style: const TextStyle(color: Color(0xFF8D6E63))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('rfid_tags')
            .doc(resident.rfidTag)
            .delete();
        await _firestore.collection('users').doc(resident.id).update({
          'rfidTag': FieldValue.delete(),
        });

        _showMessage('RFID removed from ${resident.fullName}',
            isSuccess: true);
        _loadResidents();
      } catch (e) {
        _showMessage('Error: $e', isError: true);
      }
    }
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== ADD / EDIT RESIDENT ====================
  Future<void> _addEditResident({UserModel? resident}) async {
    final isEditing = resident != null;
    final nameController =
    TextEditingController(text: resident?.fullName ?? '');
    final emailController = TextEditingController(text: resident?.email ?? '');
    final houseController =
    TextEditingController(text: resident?.houseNumber ?? '');
    final phoneController =
    TextEditingController(text: resident?.phoneNumber ?? '');
    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? '✏️ Edit Resident' : '➕ Add New Resident',
          style: const TextStyle(
              color: Color(0xFF6B5B4F), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '📧 Email (Optional)',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      helperText: 'Leave blank if resident has no email',
                      helperStyle: const TextStyle(
                          color: Color(0xFFB8A99A), fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !v.contains('@')) {
                        return 'Enter a valid email or leave blank';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: '🏠 House Number *',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '📱 Phone Number (Optional)',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                        const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
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
                        helperText:
                        'Shown after saving & emailed upon approval',
                        helperStyle: const TextStyle(
                            color: Color(0xFFB8A99A), fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                          const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFD4C4A8), width: 2),
                        ),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4C4A8).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline,
                              size: 16, color: Color(0xFF8D6E63)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'An FHM-### Resident ID will be auto-generated after saving.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF6B5B4F)),
                            ),
                          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);

              if (isEditing) {
                await _firestore
                    .collection('users')
                    .doc(resident.id)
                    .update({
                  'fullName': nameController.text.trim(),
                  'email': emailController.text.trim().toLowerCase(),
                  'houseNumber': houseController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                  if (emailController.text.trim().isNotEmpty)
                    'hasRealEmail': true,
                });
                _showMessage('Resident updated', isSuccess: true);
                _loadResidents();
              } else {
                final result = await _authService.registerResidentManually(
                  fullName: nameController.text.trim(),
                  password: passwordController.text.trim(),
                  houseNumber: houseController.text.trim(),
                  email: emailController.text.trim().isNotEmpty
                      ? emailController.text.trim()
                      : null,
                  phoneNumber: phoneController.text.trim().isNotEmpty
                      ? phoneController.text.trim()
                      : null,
                );

                if (result['success'] == true) {
                  if (mounted) {
                    await _showCredentialsDialog(
                      residentId: result['residentId'] as String,
                      password: result['password'] as String,
                      fullName: nameController.text.trim(),
                      emailProvided:
                      emailController.text.trim().isNotEmpty,
                    );
                  }
                  _loadResidents();
                } else {
                  _showMessage(result['message'] ?? 'Failed to add resident',
                      isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4C4A8),
              foregroundColor: const Color(0xFF6B5B4F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCredentialsDialog({
    required String residentId,
    required String password,
    required String fullName,
    required bool emailProvided,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
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
              Text(
                emailProvided
                    ? '⚠️ These credentials will be emailed to the resident upon approval.'
                    : '⚠️ No email provided. Give these credentials to the resident manually after approval.',
                style: const TextStyle(
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
                foregroundColor: const Color(0xFF8D6E63)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.archive_outlined,
                color: Color(0xFF8D6E63), size: 24),
            SizedBox(width: 8),
            Text('Archive Resident',
                style: TextStyle(
                    color: Color(0xFF6B5B4F),
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive ${resident.fullName}?',
              style: const TextStyle(
                  color: Color(0xFF8D6E63), fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'The resident will be moved to the archive and can be restored later.',
              style: TextStyle(
                  color: Color(0xFFB8A99A),
                  fontSize: 11,
                  height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: const TextStyle(
                    color: Color(0xFFB8A99A), fontSize: 12),
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive, size: 16),
            label: const Text('Archive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D6E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final userDoc =
      await _firestore.collection('users').doc(resident.id).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final adminAuth = _authService.getCurrentUserId();
      String adminName = 'Administrator';
      if (adminAuth != null) {
        final adminDoc =
        await _firestore.collection('users').doc(adminAuth).get();
        adminName =
            (adminDoc.get('fullName') as String?) ?? 'Administrator';
      }

      final archived = await _archiveService.archiveResident(
        userData: userData,
        originalId: resident.id!,
        adminUid: adminAuth,
        adminName: adminName,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      if (!archived) {
        _showMessage('Failed to archive resident', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      if (resident.rfidTag != null) {
        await _firestore
            .collection('rfid_tags')
            .doc(resident.rfidTag)
            .delete();
      }

      await _firestore.collection('users').doc(resident.id).delete();

      _showMessage('${resident.fullName} archived successfully',
          isSuccess: true);
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
      final userDoc =
      await _firestore.collection('users').doc(resident.id).get();
      final data = userDoc.data() as Map<String, dynamic>;

      final residentId = data['residentId'] as String?;
      final plaintextPassword = data['plaintextPassword'] as String?;
      final hasRealEmail = data['hasRealEmail'] == true;
      final storedEmail = (data['email'] as String?) ?? '';

      await _firestore.collection('users').doc(resident.id).update({
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
          fullName: resident.fullName,
          residentId: residentId,
          password: plaintextPassword,
        );

        if (emailSent) {
          await _firestore.collection('users').doc(resident.id).update({
            'plaintextPassword': FieldValue.delete(),
          });
        }

        message = emailSent
            ? '✅ ${resident.fullName} approved. Credentials emailed.'
            : '✅ Approved but email failed. Credentials: $residentId / $plaintextPassword';
      } else if (!hasRealEmail || storedEmail.isEmpty) {
        message =
        '✅ ${resident.fullName} approved. No email on file — credentials: $residentId / ${plaintextPassword ?? "N/A"}';
      } else {
        emailSent = await EmailService.sendApprovalEmail(
          storedEmail,
          resident.fullName,
        );
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
              // ==================== CUSTOM TWO-ROW HEADER ====================
              _buildHeader(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb ? 900 : double.infinity,
                    ),
                    child: _buildBody(screenWidth),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM TWO-ROW HEADER
  // Top row: back (left) + archive / records / add / refresh (right)
  // Bottom row: large title
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
        children: [
          // ---------- TOP ROW ----------
          Row(
            children: [
              _headerIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              _headerIconButton(
                icon: Icons.archive_outlined,
                tooltip: 'View Archive',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ArchivedResidentsScreen()),
                ),
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                icon: Icons.library_books_outlined,
                tooltip: 'View Records',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResidentRecordsScreen()),
                ),
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                icon: Icons.add,
                tooltip: 'Add resident',
                onTap: () => _addEditResident(),
              ),
              const SizedBox(width: 8),
              _headerIconButton(
                icon: Icons.refresh,
                tooltip: 'Refresh',
                onTap: _loadResidents,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---------- BOTTOM ROW: TITLE ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(Icons.people,
                  size: 26, color: Color(0xFFFFF8F0)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Manage Residents',
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

  Widget _headerIconButton({
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
          padding: const EdgeInsets.all(10),
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

  Widget _buildBody(double screenWidth) {
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
            Text('Loading residents...',
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
                style: const TextStyle(color: Color(0xFF8D6E63))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadResidents,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4C4A8),
                foregroundColor: const Color(0xFF6B5B4F),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final paginated = _paginatedResidents;
    final total = _totalPages;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          padding, kIsWeb ? 12 : 8, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================== SEARCH + COUNT + PAGE SIZE ====================
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
                    'Search by name, ID, house, email, or RFID tag...',
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
                    const Icon(Icons.people_outline,
                        size: 14, color: Color(0xFFB8A99A)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_filteredResidents.length} residents',
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

          // ==================== STAT CARDS ====================
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard(
                  'Total',
                  _filteredResidents.length.toString(),
                  Icons.people,
                  const Color(0xFFD4C4A8),
                  screenWidth),
              _buildStatCard(
                  'Approved',
                  _filteredResidents
                      .where((r) => r.isApproved)
                      .length
                      .toString(),
                  Icons.check_circle,
                  const Color(0xFF8D6E63),
                  screenWidth),
              _buildStatCard(
                  'RFID',
                  _filteredResidents
                      .where((r) => r.rfidTag != null)
                      .length
                      .toString(),
                  Icons.nfc,
                  const Color(0xFFC4A882),
                  screenWidth),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== LIST ====================
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
                  Icon(Icons.people, size: 48, color: Color(0xFFE0D5C1)),
                  SizedBox(height: 12),
                  Text(
                    'No residents found',
                    style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B5B4F),
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try a different search term or add a new resident',
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
                final globalIndex = _pageSize == 0
                    ? index + 1
                    : ((_currentPage - 1) * _pageSize) + index + 1;
                return _buildResidentCard(paginated[index], globalIndex);
              },
            ),

          const SizedBox(height: 12),

          // ==================== PAGINATION ====================
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
                    onPressed:
                    _currentPage > 1 ? () => _goToPage(1) : null,
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
                          color:
                          const Color(0xFFD4C4A8).withOpacity(0.15),
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

  // ==================== RESIDENT CARD ====================
  Widget _buildResidentCard(UserModel resident, int index) {
    final hasRFID = resident.rfidTag != null &&
        resident.rfidTag!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1),
        ),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: resident.isApproved
                ? const Color(0xFF8D6E63).withOpacity(0.15)
                : const Color(0xFFD4C4A8).withOpacity(0.3),
            child: Icon(
              Icons.person,
              size: 18,
              color: resident.isApproved
                  ? const Color(0xFF8D6E63)
                  : const Color(0xFFB8A99A),
            ),
          ),
          title: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFB8A99A),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  resident.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B5B4F),
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (resident.isApproved)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resident.residentId != null)
                Text(
                  resident.residentId!,
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (resident.houseNumber != null &&
                      resident.houseNumber!.isNotEmpty)
                    _miniChip(
                      Icons.home,
                      resident.houseNumber!,
                      const Color(0xFFB8A99A),
                    ),
                  if (hasRFID)
                    _miniChip(
                      Icons.nfc,
                      'Tag: ${_shortTag(resident.rfidTag!)}',
                      const Color(0xFF8D6E63),
                    )
                  else
                    _miniChip(
                      Icons.nfc,
                      'No tag',
                      const Color(0xFFD4C4A8),
                    ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            color: const Color(0xFFFFF8F0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE0D5C1)),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 16, color: Color(0xFFD4C4A8)),
                    SizedBox(width: 8),
                    Text('Edit Info', style: TextStyle(fontSize: 12))
                  ])),
              if (!resident.isApproved)
                const PopupMenuItem(
                    value: 'approve',
                    child: Row(children: [
                      Icon(Icons.check,
                          size: 16, color: Color(0xFF8D6E63)),
                      SizedBox(width: 8),
                      Text('Approve', style: TextStyle(fontSize: 12))
                    ])),
              if (!hasRFID)
                const PopupMenuItem(
                    value: 'register_rfid',
                    child: Row(children: [
                      Icon(Icons.add_circle_outline,
                          size: 16, color: Color(0xFF4CAF50)),
                      SizedBox(width: 8),
                      Text('Add RFID Tag',
                          style: TextStyle(fontSize: 12))
                    ])),
              if (hasRFID) ...[
                const PopupMenuItem(
                    value: 'add_tag',
                    child: Row(children: [
                      Icon(Icons.add_circle_outline,
                          size: 16, color: Color(0xFF4CAF50)),
                      SizedBox(width: 8),
                      Text('Add New Tag',
                          style: TextStyle(fontSize: 12))
                    ])),
                const PopupMenuItem(
                    value: 'remove_rfid',
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline,
                          size: 16, color: Color(0xFFD32F2F)),
                      SizedBox(width: 8),
                      Text('Remove Tag',
                          style: TextStyle(fontSize: 12))
                    ])),
              ],
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.archive_outlined,
                        size: 16, color: Color(0xFFD32F2F)),
                    SizedBox(width: 8),
                    Text('Archive', style: TextStyle(fontSize: 12))
                  ])),
            ],
            onSelected: (value) async {
              if (value == 'edit') {
                await _addEditResident(resident: resident);
              } else if (value == 'approve') {
                await _approveResident(resident);
              } else if (value == 'register_rfid' ||
                  value == 'add_tag') {
                await _registerRFID(resident);
              } else if (value == 'remove_rfid') {
                await _removeRFID(resident);
              } else if (value == 'delete') {
                await _deleteResident(resident);
              }
            },
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE0D5C1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resident.residentId != null) ...[
                    _buildInfoRow(Icons.badge, 'Resident ID',
                        resident.residentId!),
                    const SizedBox(height: 6),
                  ],
                  _buildInfoRow(
                      Icons.email,
                      'Email',
                      resident.email.isEmpty
                          ? 'Not provided'
                          : resident.email),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.phone, 'Phone',
                      resident.phoneNumber ?? 'Not provided'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.home, 'House',
                      resident.houseNumber ?? 'Not assigned'),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    Icons.nfc,
                    'RFID Tag',
                    hasRFID ? resident.rfidTag! : 'Not registered',
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.calendar_today, 'Registered',
                      _formatDate(resident.createdAt)),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.verified, 'Status',
                      resident.isApproved
                          ? 'Approved'
                          : 'Pending Approval'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortTag(String tag) {
    if (tag.length <= 10) return tag;
    return '${tag.substring(0, 6)}…${tag.substring(tag.length - 3)}';
  }

  Widget _miniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
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
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildStatCard(String title, String value, IconData icon,
      Color color, double screenWidth) {
    double cardWidth = screenWidth < 600 ? (screenWidth / 3) - 16 : 100;
    double iconSize = screenWidth < 600 ? 14 : 16;
    double fontSize = screenWidth < 600 ? 11 : 13;
    double labelSize = screenWidth < 600 ? 8 : 9;

    return Container(
      width: cardWidth.clamp(80, 120),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4C4A8).withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
          Text(title,
              style: TextStyle(
                  fontSize: labelSize,
                  color: color,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 6),
        SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFB8A99A),
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1)),
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}