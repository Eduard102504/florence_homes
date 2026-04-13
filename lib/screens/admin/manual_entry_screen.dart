import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      const SnackBar(
        content: Text('✅ Manual entry recorded'),
        backgroundColor: Color(0xFF8D6E63),
      ),
    );

    _nameController.clear();
    _purposeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.edit, size: 24, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 10),
            const Text(
              'Manual Gate Entry',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
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
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Entry Type Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
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
                                        Color(0xFFD4C4A8),
                                        Color(0xFFC4A882),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.category, color: Color(0xFFFFF8F0), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('🎯 Entry Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'delivery', label: Text('📦 Delivery'), icon: Icon(Icons.local_shipping, size: 16)),
                                ButtonSegment(value: 'employee', label: Text('👔 Employee'), icon: Icon(Icons.badge, size: 16)),
                                ButtonSegment(value: 'guest', label: Text('👤 Guest'), icon: Icon(Icons.person, size: 16)),
                              ],
                              selected: {_selectedEntryType},
                              onSelectionChanged: (Set<String> selection) {
                                setState(() {
                                  _selectedEntryType = selection.first;
                                });
                              },
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                      (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) return const Color(0xFFD4C4A8);
                                    return Colors.white;
                                  },
                                ),
                                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                                      (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) return const Color(0xFFFFF8F0);
                                    return const Color(0xFF6B5B4F);
                                  },
                                ),
                                side: WidgetStateProperty.resolveWith<BorderSide>(
                                      (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) return const BorderSide(color: Color(0xFFD4C4A8), width: 2);
                                    return const BorderSide(color: Color(0xFFE0D5C1), width: 1);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Person Information Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
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
                                        Color(0xFFD4C4A8),
                                        Color(0xFFC4A882),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person, color: Color(0xFFFFF8F0), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('👤 Person Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD4C4A8), size: 20),
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
                                fillColor: const Color(0xFFFFF8F0),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (value) => value?.isEmpty == true ? 'Please enter name' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Purpose Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
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
                                        Color(0xFFD4C4A8),
                                        Color(0xFFC4A882),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.description, color: Color(0xFFFFF8F0), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('💡 Purpose', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _purposeController,
                              decoration: InputDecoration(
                                labelText: 'Purpose of Entry',
                                labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 12),
                                prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFFD4C4A8), size: 20),
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
                                fillColor: const Color(0xFFFFF8F0),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              maxLines: 3,
                              validator: (value) => value?.isEmpty == true ? 'Please enter purpose' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submitManualEntry,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: const Color(0xFFD4C4A8),
                      foregroundColor: const Color(0xFF6B5B4F),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    child: const Text('✨ Record Entry ✨'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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