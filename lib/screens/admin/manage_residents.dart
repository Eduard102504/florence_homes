import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/tcp_service.dart';
import '../../models/user_model.dart';

class ManageResidents extends StatefulWidget {
  const ManageResidents({super.key});

  @override
  State<ManageResidents> createState() => _ManageResidentsState();
}

class _ManageResidentsState extends State<ManageResidents> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TCPService _tcpService = TCPService();
  List<UserModel> _residents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadResidents();
    _connectToPi();
  }

  Future<void> _connectToPi() async {
    await _tcpService.connect();
  }

  Future<void> _loadResidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .get();

      setState(() {
        _residents = snapshot.docs.map((doc) {
          return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();
        _isLoading = false;
      });

    } catch (e) {
      print('ERROR loading residents: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
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

        DocumentSnapshot updatedDoc = await _firestore
            .collection('users')
            .doc(resident.id)
            .get();

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
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
        await _firestore.collection('users').doc(resident.id).update({
          'rfidTag': FieldValue.delete(),
        });

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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== ADD/EDIT RESIDENT ====================

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
                      labelText: '👤 Full Name',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: '📧 Email',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: '🏠 House Number',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: '📱 Phone Number',
                      labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: '🔒 Password',
                        labelStyle: const TextStyle(color: Color(0xFFB8A99A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: true,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);

                if (isEditing) {
                  await _firestore.collection('users').doc(resident.id).update({
                    'fullName': nameController.text,
                    'email': emailController.text,
                    'houseNumber': houseController.text,
                    'phoneNumber': phoneController.text,
                  });
                  _showMessage('Resident updated', isSuccess: true);
                } else {
                  final result = await _authService.registerUser(
                    emailController.text,
                    passwordController.text,
                    nameController.text,
                    'resident',
                    houseController.text,
                    phoneController.text,
                  );

                  if (result['success']) {
                    _showMessage('Resident added', isSuccess: true);
                  } else {
                    _showMessage(result['message'], isError: true);
                  }
                }
                _loadResidents();
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

  Future<void> _deleteResident(UserModel resident) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resident', style: TextStyle(color: Color(0xFF6B5B4F))),
        content: Text('Are you sure you want to delete ${resident.fullName}?', style: const TextStyle(color: Color(0xFF8D6E63))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8A99A)),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        if (resident.rfidTag != null) {
          await _firestore.collection('rfid_tags').doc(resident.rfidTag).delete();
        }

        await _firestore.collection('users').doc(resident.id).delete();

        _showMessage('Resident deleted successfully', isSuccess: true);
        _loadResidents();
      } catch (e) {
        _showMessage('Error deleting resident: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveResident(UserModel resident) async {
    if (resident.isApproved) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(resident.id).update({
        'isApproved': true,
      });

      _showMessage('${resident.fullName} has been approved', isSuccess: true);
      _loadResidents();
    } catch (e) {
      _showMessage('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  List<UserModel> _getFilteredResidents() {
    if (_searchQuery.isEmpty) return _residents;

    return _residents.where((resident) {
      return resident.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (resident.houseNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          resident.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredResidents = _getFilteredResidents();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.people, size: 20, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'Manage Residents',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 15,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () => _addEditResident(),
            color: const Color(0xFFFFF8F0),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadResidents,
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBody(filteredResidents, screenWidth),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<UserModel> filteredResidents, double screenWidth) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4C4A8))),
            SizedBox(height: 16),
            Text('Loading residents...', style: TextStyle(color: Color(0xFFB8A99A))),
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
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFF8D6E63))),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        TextField(
          decoration: InputDecoration(
            hintText: '🔍 Search...',
            hintStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
            prefixIcon: const Icon(Icons.search, color: Color(0xFFD4C4A8), size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0D5C1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD4C4A8), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 12),

        // Stats Cards - USING FLEXIBLE WRAP (FIXES LINE 482 OVERFLOW)
        // This is the fix for line 482 - using Wrap instead of Row
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard('Total', filteredResidents.length.toString(), Icons.people, const Color(0xFFD4C4A8), screenWidth),
              const SizedBox(width: 8),
              _buildStatCard('Approved', filteredResidents.where((r) => r.isApproved).length.toString(), Icons.check_circle, const Color(0xFF8D6E63), screenWidth),
              const SizedBox(width: 8),
              _buildStatCard('RFID', filteredResidents.where((r) => r.rfidTag != null).length.toString(), Icons.nfc, const Color(0xFFC4A882), screenWidth),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Residents List
        filteredResidents.isEmpty
            ? SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 60, color: Color(0xFFE0D5C1)),
                const SizedBox(height: 12),
                Text('No residents found', style: TextStyle(fontSize: 14, color: Color(0xFFB8A99A))),
              ],
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredResidents.length,
          itemBuilder: (context, index) {
            final resident = filteredResidents[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    blurRadius: 4,
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
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding: const EdgeInsets.all(10),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: resident.isApproved
                        ? const Color(0xFF8D6E63).withOpacity(0.15)
                        : const Color(0xFFD4C4A8).withOpacity(0.3),
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: resident.isApproved ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A),
                    ),
                  ),
                  title: Text(
                    resident.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resident.houseNumber ?? 'No house',
                        style: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (resident.rfidTag != null)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC4A882).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('📡 RFID', style: TextStyle(fontSize: 8, color: Color(0xFF8D6E63))),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    color: const Color(0xFFFFF8F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE0D5C1)),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: Color(0xFFD4C4A8)), SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 12))])),
                      if (!resident.isApproved)
                        const PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.check, size: 16, color: Color(0xFF8D6E63)), SizedBox(width: 8), Text('Approve', style: TextStyle(fontSize: 12))])),
                      if (resident.rfidTag == null)
                        const PopupMenuItem(value: 'register_rfid', child: Row(children: [Icon(Icons.nfc, size: 16, color: Color(0xFFD4C4A8)), SizedBox(width: 8), Text('Register RFID', style: TextStyle(fontSize: 12))])),
                      if (resident.rfidTag != null)
                        const PopupMenuItem(value: 'remove_rfid', child: Row(children: [Icon(Icons.nfc, size: 16, color: Color(0xFFD32F2F)), SizedBox(width: 8), Text('Remove RFID', style: TextStyle(fontSize: 12))])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Color(0xFFD32F2F)), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 12))])),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _addEditResident(resident: resident);
                      } else if (value == 'approve') {
                        await _approveResident(resident);
                      } else if (value == 'register_rfid') {
                        await _registerRFID(resident);
                      } else if (value == 'remove_rfid') {
                        await _removeRFID(resident);
                      } else if (value == 'delete') {
                        await _deleteResident(resident);
                      }
                    },
                  ),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.email, 'Email', resident.email),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.phone, 'Phone', resident.phoneNumber ?? 'Not provided'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.home, 'House', resident.houseNumber ?? 'Not assigned'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.nfc, 'RFID', resident.rfidTag ?? 'Not registered'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.calendar_today, 'Registered', _formatDate(resident.createdAt)),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.verified, 'Status', resident.isApproved ? '✅ Approved' : '⏳ Pending'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double screenWidth) {
    double cardWidth = screenWidth < 600 ? (screenWidth / 3) - 12 : 85;
    double iconSize = screenWidth < 600 ? 14 : 16;
    double fontSize = screenWidth < 600 ? 11 : 13;
    double labelSize = screenWidth < 600 ? 8 : 9;

    return SizedBox(
      width: cardWidth.clamp(70, 95),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: labelSize, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 6),
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B5B4F)),
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