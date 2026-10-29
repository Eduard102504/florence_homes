// lib/screens/resident/my_qr_codes.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import 'qr_display_screen.dart';

class MyQRCodes extends StatefulWidget {
  const MyQRCodes({super.key});

  @override
  State<MyQRCodes> createState() => _MyQRCodesState();
}

class _MyQRCodesState extends State<MyQRCodes> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
  }

  // ==================== LOAD ====================
  Future<void> _loadQRCodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final residentId = authProvider.currentUser?.id;

      if (residentId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      QuerySnapshot snapshot = await _firestore
          .collection('visitor_qrs')
          .where('residentId', isEqualTo: residentId)
          .orderBy('generatedAt', descending: true)
          .get();

      setState(() {
        _qrCodes = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading QR codes: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ==================== FILTERS + STATUS ====================
  List<Map<String, dynamic>> _getFilteredQRCodes() {
    switch (_filter) {
      case 'active':
        return _qrCodes.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isAfter(DateTime.now());
        }).toList();
      case 'expired':
        return _qrCodes.where((qr) {
          DateTime expiresAt = DateTime.parse(qr['expiresAt']);
          return !qr['isUsed'] && expiresAt.isBefore(DateTime.now());
        }).toList();
      case 'used':
        return _qrCodes.where((qr) => qr['isUsed'] == true).toList();
      default:
        return _qrCodes;
    }
  }

  String _getStatus(Map<String, dynamic> qr) {
    DateTime expiresAt = DateTime.parse(qr['expiresAt']);
    if (qr['isUsed']) return 'Used';
    if (expiresAt.isBefore(DateTime.now())) return 'Expired';
    Duration remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours < 1) return 'Expiring soon';
    return 'Active';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return const Color(0xFF4CAF50);
      case 'Expiring soon':
        return const Color(0xFFFF9800);
      case 'Expired':
        return const Color(0xFFD32F2F);
      case 'Used':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
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
                  Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: _buildWebContent())),
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
            Expanded(child: _buildMobileContent()),
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
          const Text('Florence Homes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0), letterSpacing: 1)),
          const Text('Resident Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.dashboard, 'Dashboard', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.qr_code, 'My QR Codes', isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.person, 'Profile', onTap: () => Navigator.pop(context)),
          const Spacer(),
          ListTile(leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)), title: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)), onTap: () => Navigator.pop(context)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWebSidebarItem(IconData icon, String title, {bool isActive = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.transparent,
        leading: Icon(icon, color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)),
        title: Text(title, style: TextStyle(color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8), fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE0D5C1), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('My QR Codes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          _headerIconButton(icon: Icons.refresh, tooltip: 'Refresh', onTap: _loadQRCodes, color: const Color(0xFF8D6E63)),
        ],
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap, Color color = const Color(0xFF5D4037)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    if (_qrCodes.isEmpty) return Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code, size: 70, color: Color(0xFFE0D5C1)), SizedBox(height: 16), Text('No QR Codes Yet', style: TextStyle(fontSize: 16, color: Color(0xFF5D4037), fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Generate visitor QR codes from the home screen', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12))])));

    final filteredQRCodes = _getFilteredQRCodes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, color: Color(0xFFFFF8F0), size: 24)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total QR Codes', style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('${_qrCodes.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(_filter == 'all' ? 'All' : _filter, style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Active', 'active'),
              const SizedBox(width: 8),
              _buildFilterChip('Expired', 'expired'),
              const SizedBox(width: 8),
              _buildFilterChip('Used', 'used'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (filteredQRCodes.isEmpty)
          Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))), child: Center(child: Column(children: [const Icon(Icons.qr_code, size: 60, color: Color(0xFFE0D5C1)), const SizedBox(height: 12), Text('No ${_filter == 'all' ? '' : _filter} QR codes', style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 14))])))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredQRCodes.length,
            itemBuilder: (context, index) => _buildWebQRRow(filteredQRCodes[index]),
          ),
      ],
    );
  }

  Widget _buildWebQRRow(Map<String, dynamic> qr) {
    final status = _getStatus(qr);
    final statusColor = _getStatusColor(status);
    final expiresAt = DateTime.parse(qr['expiresAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => QRDisplayScreen(qrData: qr['qrCodeData'] ?? qr['id'], visitorName: qr['visitorName'], isSavedQR: true)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.qr_code, color: Color(0xFFFFF8F0), size: 22)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(qr['visitorName'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)), overflow: TextOverflow.ellipsis, maxLines: 1), Text('For: ${qr['residentName']}', style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1)])),
              Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.access_time, size: 12, color: Color(0xFF8D6E63)), const SizedBox(width: 4), Expanded(child: Text(DateFormat('MMM dd, hh:mm a').format(expiresAt), style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1))]), const SizedBox(height: 4), Row(children: [const Icon(Icons.calendar_today, size: 12, color: Color(0xFF8D6E63)), const SizedBox(width: 4), Expanded(child: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(qr['generatedAt'])), style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1))])])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor)), child: Text(status == 'Expiring soon' ? '⚠️ $status' : status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 📱 MOBILE COMPONENTS
  // ============================================================

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(color: Color(0xFF5D4037), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.qr_code, size: 120, color: Colors.white.withOpacity(0.05))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('My QR Codes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
                  GestureDetector(onTap: _loadQRCodes, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, color: Color(0xFFFFF8F0), size: 20))),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Visitor Codes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFD4C4A8)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFD32F2F))));
    if (_qrCodes.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code, size: 70, color: Color(0xFFD4C4A8)), SizedBox(height: 16), Text('No QR Codes Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))), SizedBox(height: 8), Text('Generate visitor QR codes from the home screen', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12), textAlign: TextAlign.center)]));

    final filteredQRCodes = _getFilteredQRCodes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, color: Color(0xFFFFF8F0), size: 26)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total QR Codes', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('${_qrCodes.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))])), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(_filter == 'all' ? 'All' : _filter, style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)))]),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [_buildFilterChip('All', 'all'), const SizedBox(width: 8), _buildFilterChip('Active', 'active'), const SizedBox(width: 8), _buildFilterChip('Expired', 'expired'), const SizedBox(width: 8), _buildFilterChip('Used', 'used')]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredQRCodes.isEmpty
              ? Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))), child: Center(child: Column(children: [const Icon(Icons.qr_code, size: 56, color: Color(0xFFD4C4A8)), const SizedBox(height: 12), Text('No ${_filter == 'all' ? '' : _filter} QR codes', style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13))])))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filteredQRCodes.length,
            itemBuilder: (context, index) => _buildMobileQRCard(filteredQRCodes[index]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMobileQRCard(Map<String, dynamic> qr) {
    final status = _getStatus(qr);
    final statusColor = _getStatusColor(status);
    final expiresAt = DateTime.parse(qr['expiresAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QRDisplayScreen(qrData: qr['qrCodeData'] ?? qr['id'], visitorName: qr['visitorName'], isSavedQR: true))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.qr_code, color: Color(0xFFFFF8F0), size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(qr['visitorName'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)), overflow: TextOverflow.ellipsis, maxLines: 1), Text('For: ${qr['residentName']}', style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1)])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)), child: Text(status == 'Expiring soon' ? '⚠️ $status' : status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600))),
                ],
              ),
              const Divider(color: Color(0xFFE0D5C1), height: 24),
              Row(children: [const Icon(Icons.access_time, size: 14, color: Color(0xFFD4C4A8)), const SizedBox(width: 6), Expanded(child: Text('Expires: ${DateFormat('MMM dd, hh:mm a').format(expiresAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1))]),
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.calendar_today, size: 14, color: Color(0xFFD4C4A8)), const SizedBox(width: 6), Expanded(child: Text('Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(qr['generatedAt']))}', style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)), overflow: TextOverflow.ellipsis, maxLines: 1))]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: _filter == value ? const Color(0xFFFFF8F0) : const Color(0xFF5D4037), fontSize: 13, fontWeight: FontWeight.w500)),
      selected: _filter == value,
      onSelected: (selected) => setState(() => _filter = value),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF5D4037),
      checkmarkColor: const Color(0xFFFFF8F0),
      side: BorderSide(color: _filter == value ? const Color(0xFF5D4037) : const Color(0xFFE0D5C1), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}