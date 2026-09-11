import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/gate_service.dart';
import '../../services/tcp_service.dart';
import '../../providers/auth_provider.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final GateService _gateService = GateService();
  final TCPService _tcpService = TCPService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedEntryType = 'delivery';
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isGateOpening = false;

  @override
  void initState() {
    super.initState();
    _connectToPi();
  }

  Future<void> _connectToPi() async {
    await _tcpService.connect();
  }

  Future<void> _openGate() async {
    if (_isGateOpening) return;

    setState(() => _isGateOpening = true);

    try {
      bool success = await _tcpService.openGate();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gate opened successfully'), backgroundColor: Color(0xFF8D6E63)),
        );
      } else {
        await _tcpService.connect();
        bool retry = await _tcpService.openGate();
        if (retry) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gate opened after reconnection'), backgroundColor: Color(0xFF8D6E63)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to open gate. Check connection.'), backgroundColor: Color(0xFFD32F2F)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD32F2F)),
      );
    } finally {
      setState(() => _isGateOpening = false);
    }
  }

  Future<void> _submitManualEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminId = authProvider.currentUser?.id;

    String residentName;
    String residentId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

    if (_selectedEntryType == 'delivery') {
      residentName = '📦 Delivery: ${_nameController.text}';
    } else if (_selectedEntryType == 'employee') {
      residentName = '👔 Employee: ${_nameController.text}';
    } else {
      residentName = '👤 Guest: ${_nameController.text}';
    }

    try {
      await _firestore.collection('gate_entries').add({
        'residentId': residentId,
        'residentName': residentName,
        'entryType': 'manual',
        'timestamp': DateTime.now().toIso8601String(),
        'visitorName': _nameController.text,
        'status': 'entry',
      });

      await _firestore.collection('manual_openings').add({
        'adminId': adminId,
        'entryType': _selectedEntryType,
        'personName': _nameController.text,
        'reason': _selectedEntryType == 'guest' ? _reasonController.text : null,
        'timestamp': DateTime.now(),
        'status': 'completed',
      });

      bool gateOpened = await _tcpService.openGate();

      if (gateOpened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry recorded and gate opened'), backgroundColor: Color(0xFF8D6E63)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry recorded but failed to open gate'), backgroundColor: Color(0xFFFF9800)),
        );
      }

      _nameController.clear();
      _reasonController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD32F2F)),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.edit, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Open Gate Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.2),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFF9800), Color(0xFFF5A623)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.door_front_door, size: 32, color: Color(0xFFFFF8F0)),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Quick Gate Control',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B5B4F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _isGateOpening ? null : _openGate,
                              icon: _isGateOpening
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)),
                                ),
                              )
                                  : const Icon(Icons.open_in_new, size: 18),
                              label: Text(_isGateOpening ? 'Opening...' : 'Quick Open Gate'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                backgroundColor: const Color(0xFFFF9800),
                                foregroundColor: const Color(0xFFFFF8F0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Entry Type Selection
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.2),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.category, color: Color(0xFF8D6E63), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Entry Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B5B4F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEntryTypeButton('delivery', Icons.local_shipping, '📦 Delivery'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildEntryTypeButton('employee', Icons.work, '👔 Employee'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildEntryTypeButton('guest', Icons.people, '👤 Guest'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Person Information
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.2),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person, color: Color(0xFF8D6E63), size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Person Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B5B4F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: '👤 Full Name',
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
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter name';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reason for Entry - ONLY for Guest
                  if (_selectedEntryType == 'guest') ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4C4A8).withOpacity(0.2),
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4C4A8).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.info, color: Color(0xFF8D6E63), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Reason for Entry',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6B5B4F),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _reasonController,
                                decoration: InputDecoration(
                                  labelText: '💡 Reason',
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
                                  hintText: 'e.g., Visiting family, Friend visit',
                                ),
                                maxLines: 2,
                                validator: (value) {
                                  if (_selectedEntryType == 'guest' && (value == null || value.isEmpty)) {
                                    return 'Please enter a reason';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitManualEntry,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xFFD4C4A8),
                      foregroundColor: const Color(0xFF6B5B4F),
                      elevation: 3,
                      shadowColor: const Color(0xFFD4C4A8).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B5B4F)),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.record_voice_over, size: 20),
                        SizedBox(width: 8),
                        Text('Record Entry & Open Gate'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTypeButton(String value, IconData icon, String label) {
    bool isSelected = _selectedEntryType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEntryType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)],
          )
              : null,
          color: isSelected ? null : const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4C4A8) : const Color(0xFFE0D5C1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF8D6E63),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFFFFF8F0) : const Color(0xFF6B5B4F),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}