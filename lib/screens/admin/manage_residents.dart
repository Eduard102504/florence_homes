import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/nfc_service.dart';
import '../../models/user_model.dart';

class ManageResidents extends StatefulWidget {
  const ManageResidents({super.key});

  @override
  State<ManageResidents> createState() => _ManageResidentsState();
}

class _ManageResidentsState extends State<ManageResidents> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NFCService _nfcService = NFCService();
  List<UserModel> _residents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadResidents();
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

  // ==================== RFID REGISTRATION METHODS ====================

  Future<void> _registerRFID(UserModel resident) async {
    bool hasNFC = await _nfcService.checkNFC();

    if (!hasNFC) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC not available on this device'), backgroundColor: Colors.red),
      );
      return;
    }

    _showNFCScanDialog(resident);
  }

  void _showNFCScanDialog(UserModel resident) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Scan RFID Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text('Tap RFID tag for ${resident.fullName}'),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _nfcService.stopScan();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    _nfcService.startScan(context, (tagId) {
      _nfcService.stopScan();
      Navigator.pop(context);

      _nfcService.registerRFID(tagId, resident.id!, resident.fullName).then((success) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('RFID registered for ${resident.fullName}'), backgroundColor: Colors.green),
          );
          _loadResidents();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to register RFID'), backgroundColor: Colors.red),
          );
        }
      });
    });
  }

  Future<void> _removeRFID(UserModel resident) async {
    if (resident.rfidTag == null) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove RFID'),
        content: Text('Remove RFID tag from ${resident.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RFID removed from ${resident.fullName}'),
            backgroundColor: Colors.green,
          ),
        );

        _loadResidents();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        title: Text(isEditing ? 'Edit Resident' : 'Add New Resident'),
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
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: houseController,
                    decoration: const InputDecoration(
                      labelText: 'House Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resident updated')),
                  );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Resident added')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'])),
                    );
                  }
                }
                _loadResidents();
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  // ==================== DELETE RESIDENT ====================

  Future<void> _deleteResident(UserModel resident) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resident'),
        content: Text('Are you sure you want to delete ${resident.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resident deleted successfully')),
        );

        _loadResidents();
      } catch (e) {
        print('Error deleting resident: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting resident: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== APPROVE RESIDENT ====================

  Future<void> _approveResident(UserModel resident) async {
    if (resident.isApproved) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(resident.id).update({
        'isApproved': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${resident.fullName} has been approved')),
      );

      _loadResidents();
    } catch (e) {
      print('Error approving resident: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // ==================== FILTER RESIDENTS ====================

  List<UserModel> _getFilteredResidents() {
    if (_searchQuery.isEmpty) return _residents;

    return _residents.where((resident) {
      return resident.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (resident.houseNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          resident.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    final filteredResidents = _getFilteredResidents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Residents'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addEditResident(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResidents,
          ),
        ],
      ),
      body: _buildBody(filteredResidents),
    );
  }

  Widget _buildBody(List<UserModel> filteredResidents) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading residents...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadResidents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, house number, or email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Stats Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  filteredResidents.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  filteredResidents.where((r) => r.isApproved).length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'RFID',
                  filteredResidents.where((r) => r.rfidTag != null).length.toString(),
                  Icons.nfc,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Residents List
        Expanded(
          child: filteredResidents.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No residents found',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredResidents.length,
            itemBuilder: (context, index) {
              final resident = filteredResidents[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: resident.isApproved
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      Icons.person,
                      color: resident.isApproved ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    resident.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resident.houseNumber ?? 'No house number'),
                      if (resident.rfidTag != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RFID Registered',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (!resident.isApproved)
                        const PopupMenuItem(
                          value: 'approve',
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Approve'),
                            ],
                          ),
                        ),
                      if (resident.rfidTag == null)
                        const PopupMenuItem(
                          value: 'register_rfid',
                          child: Row(
                            children: [
                              Icon(Icons.nfc, size: 20, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Register RFID'),
                            ],
                          ),
                        ),
                      if (resident.rfidTag != null)
                        const PopupMenuItem(
                          value: 'remove_rfid',
                          child: Row(
                            children: [
                              Icon(Icons.nfc, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remove RFID'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(Icons.email, 'Email', resident.email),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.phone,
                            'Phone',
                            resident.phoneNumber ?? 'Not provided',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.home,
                            'House Number',
                            resident.houseNumber ?? 'Not assigned',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.nfc,
                            'RFID Tag',
                            resident.rfidTag ?? 'Not registered',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Registered',
                            _formatDate(resident.createdAt),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.verified,
                            'Status',
                            resident.isApproved ? 'Approved' : 'Pending',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}