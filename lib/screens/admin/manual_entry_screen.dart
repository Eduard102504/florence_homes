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

  // Common fields
  String _selectedEntryType = 'employee';
  final _nameController = TextEditingController();

  // Employee fields
  String _selectedEmployeeWork = 'Maintenance';
  final List<String> _employeeWorkTypes = [
    'Maintenance',
    'Gardener',
    'Security',
    'Housekeeping',
    'Office Staff',
    'Construction',
    'Other'
  ];

  // Delivery fields
  String _selectedDeliveryType = 'Parcel';
  String _selectedDeliveryCompany = 'Shopee';
  final TextEditingController _deliveryDetailsController = TextEditingController();
  final TextEditingController _deliveryBlockController = TextEditingController();

  final List<String> _deliveryTypes = ['Parcel', 'Food', 'Water', 'Bill', 'Package', 'Other'];
  final List<String> _deliveryCompanies = [
    'Shopee', 'Lazada', 'J&T', 'Flash Express', 'Grab', 'Foodpanda',
    'Water Delivery', 'Meralco', 'Maynilad', 'PLDT', 'Globe', 'Other'
  ];

  // Guest fields
  final TextEditingController _guestPurposeController = TextEditingController();
  String _selectedGuestPurpose = 'Personal';
  final List<String> _guestPurposes = ['Personal', 'Business', 'Official', 'Interview', 'Tour', 'Other'];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _deliveryDetailsController.dispose();
    _deliveryBlockController.dispose();
    _guestPurposeController.dispose();
    super.dispose();
  }

  Future<void> _submitManualEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminId = authProvider.currentUser?.id;
    final adminName = authProvider.currentUser?.fullName ?? 'Admin';

    String entryDescription = '';
    String visitorInfo = '';

    // Build description based on entry type
    switch (_selectedEntryType) {
      case 'employee':
        entryDescription = 'Employee - $_selectedEmployeeWork';
        visitorInfo = 'Work: $_selectedEmployeeWork';
        break;
      case 'delivery':
        entryDescription = 'Delivery - $_selectedDeliveryType from $_selectedDeliveryCompany';
        visitorInfo = 'Type: $_selectedDeliveryType | Company: $_selectedDeliveryCompany';
        if (_deliveryDetailsController.text.isNotEmpty) {
          visitorInfo += ' | Details: ${_deliveryDetailsController.text}';
        }
        if (_deliveryBlockController.text.isNotEmpty) {
          visitorInfo += ' | Block: ${_deliveryBlockController.text}';
        }
        break;
      case 'guest':
        entryDescription = 'Guest - $_selectedGuestPurpose';
        visitorInfo = 'Purpose: $_selectedGuestPurpose';
        if (_guestPurposeController.text.isNotEmpty) {
          visitorInfo += ' | Details: ${_guestPurposeController.text}';
        }
        break;
    }

    try {
      // Save to manual_openings collection
      await _firestore.collection('manual_openings').add({
        'adminId': adminId,
        'adminName': adminName,
        'entryType': _selectedEntryType,
        'personName': _nameController.text,
        'description': entryDescription,
        'visitorInfo': visitorInfo,
        'timestamp': DateTime.now(),
        'status': 'completed',
        'employeeWork': _selectedEntryType == 'employee' ? _selectedEmployeeWork : null,
        'deliveryType': _selectedEntryType == 'delivery' ? _selectedDeliveryType : null,
        'deliveryCompany': _selectedEntryType == 'delivery' ? _selectedDeliveryCompany : null,
        'deliveryDetails': _selectedEntryType == 'delivery' ? _deliveryDetailsController.text : null,
        'deliveryBlock': _selectedEntryType == 'delivery' ? _deliveryBlockController.text : null,
        'guestPurpose': _selectedEntryType == 'guest' ? _selectedGuestPurpose : null,
        'guestDetails': _selectedEntryType == 'guest' ? _guestPurposeController.text : null,
      });

      // Save to gate_entries collection
      await _gateService.recordGateEntry(
        residentId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        residentName: _nameController.text,
        entryType: 'MANUAL',
        visitorName: entryDescription,
        status: 'entry',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual entry recorded successfully')),
      );

      // Clear form
      _nameController.clear();
      _deliveryDetailsController.clear();
      _deliveryBlockController.clear();
      _guestPurposeController.clear();
      _selectedEmployeeWork = 'Maintenance';
      _selectedDeliveryType = 'Parcel';
      _selectedDeliveryCompany = 'Shopee';
      _selectedGuestPurpose = 'Personal';

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Gate Entry'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entry Type Selection - FIXED: Hindi na napuputol
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Entry Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // Use Wrap para hindi maputol ang mga salita
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildEntryTypeChip('employee', 'Employee'),
                          _buildEntryTypeChip('delivery', 'Delivery'),
                          _buildEntryTypeChip('guest', 'Guest'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Name Field (common to all)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Dynamic fields based on entry type
              if (_selectedEntryType == 'employee') _buildEmployeeFields(),
              if (_selectedEntryType == 'delivery') _buildDeliveryFields(),
              if (_selectedEntryType == 'guest') _buildGuestFields(),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitManualEntry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Record Entry'),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Custom chip para sa entry type selection
  Widget _buildEntryTypeChip(String value, String label) {
    final isSelected = _selectedEntryType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedEntryType = value;
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.green,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  Widget _buildEmployeeFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedEmployeeWork,
          decoration: const InputDecoration(
            labelText: 'Work Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.work),
          ),
          items: _employeeWorkTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployeeWork = value!;
            });
          },
          // Para laging nasa ibaba ang dropdown
          menuMaxHeight: 300,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedDeliveryType,
          decoration: const InputDecoration(
            labelText: 'Delivery Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_shipping),
          ),
          items: _deliveryTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDeliveryType = value!;
            });
          },
          menuMaxHeight: 300,
          isExpanded: true,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedDeliveryCompany,
          decoration: const InputDecoration(
            labelText: 'Courier/Company',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          items: _deliveryCompanies.map((company) {
            return DropdownMenuItem(
              value: company,
              child: Text(company),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDeliveryCompany = value!;
            });
          },
          menuMaxHeight: 300,
          isExpanded: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _deliveryDetailsController,
          decoration: const InputDecoration(
            labelText: 'Delivery Details (optional)',
            hintText: 'e.g., 2 boxes, fragile items',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _deliveryBlockController,
          decoration: const InputDecoration(
            labelText: 'Block/Lot Number (optional)',
            hintText: 'e.g., Block A, Lot 12',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedGuestPurpose,
          decoration: const InputDecoration(
            labelText: 'Purpose of Visit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.flag),
          ),
          items: _guestPurposes.map((purpose) {
            return DropdownMenuItem(
              value: purpose,
              child: Text(purpose),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedGuestPurpose = value!;
            });
          },
          menuMaxHeight: 300,
          isExpanded: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestPurposeController,
          decoration: const InputDecoration(
            labelText: 'Additional Details (optional)',
            hintText: 'e.g., Meeting with resident, Interview',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit_note),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}