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
  String? _dateError;
  String? _timeError;

  final QRService _qrService = QRService();

  // Check if selected date is valid (not in past)
  bool _isDateValid() {
    DateTime today = DateTime.now();
    DateTime selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    DateTime todayDate = DateTime(today.year, today.month, today.day);

    return selectedDate.isAfter(todayDate) || selectedDate.isAtSameMomentAs(todayDate);
  }

  // Check if selected time is valid for today
  bool _isTimeValid() {
    DateTime now = DateTime.now();

    // If date is in the future, any time is valid
    if (_selectedDate.isAfter(DateTime(now.year, now.month, now.day))) {
      return true;
    }

    // If date is today, time must be in the future
    if (_selectedDate.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      final nowTime = TimeOfDay.fromDateTime(now);
      if (_selectedTime.hour < nowTime.hour) {
        return false;
      }
      if (_selectedTime.hour == nowTime.hour && _selectedTime.minute <= nowTime.minute) {
        return false;
      }
      return true;
    }

    return false;
  }

  void _validateDateTime() {
    setState(() {
      if (!_isDateValid()) {
        _dateError = 'Please select a future date';
      } else {
        _dateError = null;
      }

      if (!_isTimeValid()) {
        _timeError = 'Please select a future time';
      } else {
        _timeError = null;
      }
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4C4A8),
              onPrimary: Color(0xFFFFF8F0),
              surface: Color(0xFFFFF8F0),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _validateDateTime();

        // If date changed, also validate time
        if (!_isTimeValid() && _selectedDate.isAtSameMomentAs(DateTime.now())) {
          // Reset time to current time + 1 hour if invalid
          final now = DateTime.now();
          final newTime = TimeOfDay(
            hour: now.hour + 1 > 23 ? 23 : now.hour + 1,
            minute: now.minute,
          );
          _selectedTime = newTime;
          _validateDateTime();
        }
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4C4A8),
              onPrimary: Color(0xFFFFF8F0),
              surface: Color(0xFFFFF8F0),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
        _validateDateTime();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.qr_code, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'Generate Visitor QR',
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
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Color(0xFFFFF8F0), size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Visitor QR Code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B5B4F),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generate a temporary QR code for your visitors',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFB8A99A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visitor Information Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
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
                              child: const Icon(Icons.person_outline, color: Color(0xFF8D6E63), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Visitor Information',
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
                          controller: _visitorNameController,
                          decoration: InputDecoration(
                            labelText: 'Visitor Name',
                            labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
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
                            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD4C4A8)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter visitor name';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visit Details Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
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
                              child: const Icon(Icons.calendar_today, color: Color(0xFF8D6E63), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Visit Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B5B4F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4C4A8).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today, color: Color(0xFF8D6E63), size: 18),
                          ),
                          title: const Text(
                            'Visit Date',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B5B4F)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMMM dd, yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF5D4037)),
                              ),
                              if (_dateError != null)
                                Text(
                                  _dateError!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFD32F2F)),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4C4A8)),
                          onTap: _selectDate,
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4C4A8).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time, color: Color(0xFF8D6E63), size: 18),
                          ),
                          title: const Text(
                            'Visit Time',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B5B4F)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF5D4037)),
                              ),
                              if (_timeError != null)
                                Text(
                                  _timeError!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFD32F2F)),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4C4A8)),
                          onTap: _selectTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Validity Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
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
                              child: const Icon(Icons.timer_outlined, color: Color(0xFF8D6E63), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'QR Code Validity',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B5B4F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _validityHours,
                          decoration: InputDecoration(
                            labelText: 'Validity Period',
                            labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
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
                            prefixIcon: const Icon(Icons.hourglass_empty, color: Color(0xFFD4C4A8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 hour', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 2, child: Text('2 hours', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 4, child: Text('4 hours', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 8, child: Text('8 hours', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 12, child: Text('12 hours', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 24, child: Text('24 hours', style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(value: 48, child: Text('48 hours', style: TextStyle(fontSize: 14))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _validityHours = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Generate Button
                  ElevatedButton(
                    onPressed: (_isGenerating || _dateError != null || _timeError != null) ? null : _generateQR,
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
                    child: _isGenerating
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B5B4F)),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 20),
                        SizedBox(width: 8),
                        Text('Generate QR Code'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4C4A8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4C4A8).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF8D6E63)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The QR code will be valid for the selected duration. Share it with your visitor for gate access. Only future dates and times can be selected.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8D6E63),
                              height: 1.3,
                            ),
                          ),
                        ),
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

  Future<void> _generateQR() async {
    if (_formKey.currentState!.validate()) {
      // Final validation before generating
      if (!_isDateValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid future date'), backgroundColor: Color(0xFFD32F2F)),
        );
        return;
      }

      if (!_isTimeValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid future time'), backgroundColor: Color(0xFFD32F2F)),
        );
        return;
      }

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