// lib/screens/admin/generate_visitor_qr.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ==================== VALIDATION ====================
  bool _isDateValid() {
    DateTime today = DateTime.now();
    DateTime selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    DateTime todayDate = DateTime(today.year, today.month, today.day);
    return selectedDate.isAfter(todayDate) ||
        selectedDate.isAtSameMomentAs(todayDate);
  }

  bool _isTimeValid() {
    DateTime now = DateTime.now();
    if (_selectedDate.isAfter(DateTime(now.year, now.month, now.day))) {
      return true;
    }
    if (_selectedDate.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      final nowTime = TimeOfDay.fromDateTime(now);
      if (_selectedTime.hour < nowTime.hour) return false;
      if (_selectedTime.hour == nowTime.hour &&
          _selectedTime.minute <= nowTime.minute) return false;
      return true;
    }
    return false;
  }

  void _validateDateTime() {
    setState(() {
      _dateError = _isDateValid() ? null : 'Please select a future date';
      _timeError = _isTimeValid() ? null : 'Please select a future time';
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
              primary: Color(0xFF5D4037),
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
        if (!_isTimeValid() &&
            _selectedDate.isAtSameMomentAs(DateTime.now())) {
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
              primary: Color(0xFF5D4037),
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

  // ==================== GENERATE ====================
  Future<void> _generateQR() async {
    if (_formKey.currentState!.validate()) {
      if (!_isDateValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a valid future date'),
              backgroundColor: Color(0xFFD32F2F)),
        );
        return;
      }

      if (!_isTimeValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a valid future time'),
              backgroundColor: Color(0xFFD32F2F)),
        );
        return;
      }

      setState(() => _isGenerating = true);

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

      setState(() => _isGenerating = false);

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

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: _buildFormContent(),
                ),
              ),
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
          const Text('Florence Homes',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFF8F0),
                  letterSpacing: 1)),
          const Text('Resident Portal',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.qr_code, 'Generate QR',
              isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.history, 'Gate History',
              onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.person, 'Profile',
              onTap: () => Navigator.pop(context)),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)),
            title: const Text('Back to Dashboard',
                style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title,
      {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? const Color(0xFFD4C4A8).withOpacity(0.15)
            : Colors.transparent,
        leading: Icon(icon,
            color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title,
            style: TextStyle(
                color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Generate Visitor QR',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037))),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _buildFormContent(),
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF5D4037),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.qr_code,
                  size: 120, color: Colors.white.withOpacity(0.05))),
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
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back,
                              color: Color(0xFFFFF8F0), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Generate QR',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFFFFF8F0),
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Visitor QR Code',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 SHARED FORM CONTENT
  // ============================================================

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ]),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF5D4037),
                      Color(0xFF8D6E63)
                    ]),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.qr_code_scanner,
                    color: Color(0xFFFFF8F0), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Visitor QR Code',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037))),
                    SizedBox(height: 4),
                    Text('Generate a temporary QR code for your visitors',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF8D6E63))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Visitor info
        _buildSectionCard(
          icon: Icons.person_outline,
          title: 'Visitor Information',
          children: [
            TextFormField(
              controller: _visitorNameController,
              decoration: InputDecoration(
                labelText: 'Visitor Name',
                labelStyle:
                const TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                    const BorderSide(color: Color(0xFF5D4037), width: 2)),
                filled: true,
                fillColor: const Color(0xFFFFF8F0),
                prefixIcon: const Icon(Icons.person_outline,
                    color: Color(0xFFD4C4A8)),
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
        const SizedBox(height: 16),

        // Visit details
        _buildSectionCard(
          icon: Icons.calendar_today,
          title: 'Visit Details',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_today,
                    color: Color(0xFF8D6E63), size: 18),
              ),
              title: const Text('Visit Date',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5D4037))),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D4037))),
                  if (_dateError != null)
                    Text(_dateError!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFD32F2F))),
                ],
              ),
              trailing:
              const Icon(Icons.chevron_right, color: Color(0xFFD4C4A8)),
              onTap: _selectDate,
            ),
            const Divider(color: Color(0xFFE0D5C1), height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFD4C4A8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.access_time,
                    color: Color(0xFF8D6E63), size: 18),
              ),
              title: const Text('Visit Time',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5D4037))),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedTime.format(context),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D4037))),
                  if (_timeError != null)
                    Text(_timeError!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFD32F2F))),
                ],
              ),
              trailing:
              const Icon(Icons.chevron_right, color: Color(0xFFD4C4A8)),
              onTap: _selectTime,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Validity
        _buildSectionCard(
          icon: Icons.timer_outlined,
          title: 'QR Code Validity',
          children: [
            DropdownButtonFormField<int>(
              value: _validityHours,
              decoration: InputDecoration(
                labelText: 'Validity Period',
                labelStyle:
                const TextStyle(color: Color(0xFFB8A99A), fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0D5C1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                    const BorderSide(color: Color(0xFF5D4037), width: 2)),
                filled: true,
                fillColor: const Color(0xFFFFF8F0),
                prefixIcon: const Icon(Icons.hourglass_empty,
                    color: Color(0xFFD4C4A8)),
              ),
              items: const [
                DropdownMenuItem(
                    value: 1,
                    child: Text('1 hour', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 2,
                    child: Text('2 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 4,
                    child: Text('4 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 8,
                    child: Text('8 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 12,
                    child: Text('12 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 24,
                    child: Text('24 hours', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(
                    value: 48,
                    child: Text('48 hours', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (value) {
                setState(() => _validityHours = value!);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Generate button
        ElevatedButton(
          onPressed: (_isGenerating || _dateError != null || _timeError != null)
              ? null
              : _generateQR,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: const Color(0xFFFFF8F0),
              elevation: 3,
              shadowColor: const Color(0xFF5D4037).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
          child: _isGenerating
              ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0))))
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

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF8D6E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: const Color(0xFF8D6E63).withOpacity(0.3))),
          child: Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF8D6E63)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The QR code will be valid for the selected duration. Share it with your visitor for gate access. Only future dates and times can be selected.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF8D6E63), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD4C4A8).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: const Color(0xFF5D4037), size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037))),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    super.dispose();
  }
}