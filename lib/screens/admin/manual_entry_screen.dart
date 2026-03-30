import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/gate_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final GateService _gateService = GateService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  String _selectedEntryType = 'delivery';

  Future<void> _submitManualEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminId = authProvider.currentUser?.id;

    await _firestore.collection('manual_openings').add({
      'adminId': adminId,
      'entryType': _selectedEntryType,
      'personName': _nameController.text,
      'purpose': _purposeController.text,
      'timestamp': DateTime.now(),
      'status': 'completed',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual entry recorded')),
    );

    _nameController.clear();
    _purposeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Gate Entry'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Entry Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'delivery', label: Text('Delivery')),
                          ButtonSegment(value: 'employee', label: Text('Employee')),
                          ButtonSegment(value: 'guest', label: Text('Guest')),
                        ],
                        selected: {_selectedEntryType},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() {
                            _selectedEntryType = selection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purpose';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitManualEntry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: const Text('Record Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    super.dispose();
  }
}