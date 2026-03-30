import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/qr_service.dart';
import '../../providers/auth_provider.dart';
import 'qr_display_screen.dart';

class GenerateVisitorQR extends StatefulWidget {
  const GenerateVisitorQR({super.key});

  @override
  State<GenerateVisitorQR> createState() => _GenerateVisitorQRState();
}

class _GenerateVisitorQRState extends State<GenerateVisitorQR> {
  final _formKey = GlobalKey<FormState>();
  final _visitorNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _validityHours = 24;
  bool _isGenerating = false;

  final QRService _qrService = QRService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Visitor QR Code'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Visitor Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _visitorNameController,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter visitor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Visit Date'),
                subtitle: Text(DateFormat('MMMM dd, yyyy').format(_selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Visit Time'),
                subtitle: Text(_selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (time != null) {
                    setState(() {
                      _selectedTime = time;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'QR Code Validity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _validityHours,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 hour')),
                  DropdownMenuItem(value: 2, child: Text('2 hours')),
                  DropdownMenuItem(value: 4, child: Text('4 hours')),
                  DropdownMenuItem(value: 8, child: Text('8 hours')),
                  DropdownMenuItem(value: 12, child: Text('12 hours')),
                  DropdownMenuItem(value: 24, child: Text('24 hours')),
                  DropdownMenuItem(value: 48, child: Text('48 hours')),
                ],
                onChanged: (value) {
                  setState(() {
                    _validityHours = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateQR,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator()
                    : const Text('Generate QR Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateQR() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isGenerating = true;
      });

      DateTime visitDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final residentId = authProvider.currentUser?.id ?? '';
      final residentName = authProvider.currentUser?.fullName ?? 'Resident';

      String qrData = await _qrService.generateVisitorQR(
        residentId: residentId,
        residentName: residentName,
        visitorName: _visitorNameController.text,
        visitDate: visitDateTime,
        validityHours: _validityHours,
      );

      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRDisplayScreen(
              qrData: qrData,
              visitorName: _visitorNameController.text,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    super.dispose();
  }
}