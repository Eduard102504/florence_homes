// lib/screens/admin/scanner_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ScannerManagementScreen extends StatefulWidget {
  const ScannerManagementScreen({super.key});

  @override
  State<ScannerManagementScreen> createState() => _ScannerManagementScreenState();
}

class _ScannerManagementScreenState extends State<ScannerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _autoGate = true;
  String? _scannerIp;
  String _scannerPort = '8081';
  bool _isScannerConnected = false;

  final MobileScannerController _cameraController = MobileScannerController();
  bool _isQrScanning = false;
  bool _isOpeningGate = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _connectToScanner();
  }

  // ==================== SETTINGS / CONNECTION ====================
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoGate = prefs.getBool('auto_gate') ?? true;
      _scannerIp = prefs.getString('scanner_ip') ?? '192.168.1.9';
      _scannerPort = prefs.getString('scanner_port') ?? '8081';
    });
  }

  Future<void> _connectToScanner() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_scannerIp:$_scannerPort/status'))
          .timeout(const Duration(seconds: 3));

      setState(() {
        _isScannerConnected = response.statusCode == 200;
      });
      print('Scanner connection: ${response.statusCode}');
    } catch (e) {
      print('Scanner connection failed: $e');
      setState(() {
        _isScannerConnected = false;
      });
    }
  }

  // ==================== GATE OPEN ====================
  Future<void> _openGate() async {
    if (_isOpeningGate) return;

    setState(() {
      _isOpeningGate = true;
    });

    try {
      print('🚪 Opening gate via HTTP to $_scannerIp:$_scannerPort/open');
      final response = await http
          .post(
        Uri.parse('http://$_scannerIp:$_scannerPort/open'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': 'open'}),
      )
          .timeout(const Duration(seconds: 5));

      print('✅ Gate open response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gate opened successfully'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gate response: ${response.statusCode}'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('❌ Error opening gate: $e');
      try {
        final response = await http
            .get(Uri.parse('http://$_scannerIp:$_scannerPort/open'))
            .timeout(const Duration(seconds: 3));
        print('✅ Gate open via GET: ${response.statusCode}');
      } catch (e2) {
        print('❌ Both gate opening methods failed: $e2');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open gate. Check connection.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isOpeningGate = false;
      });
    }
  }

  // ==================== QR PROCESSING ====================
  Future<void> _processQRCode(String qrData) async {
    if (_isQrScanning) return;

    print('🔍 QR Code detected: $qrData');

    setState(() {
      _isQrScanning = true;
    });

    try {
      Map<String, dynamic> qrInfo;
      try {
        String decoded = utf8.decode(base64.decode(qrData));
        qrInfo = json.decode(decoded);
      } catch (e) {
        qrInfo = json.decode(qrData);
      }

      String qrId = qrInfo['id'];

      DocumentSnapshot qrDoc = await _firestore.collection('visitor_qrs').doc(qrId).get();

      if (!qrDoc.exists) {
        _showResultDialog(false, 'Invalid QR Code');
        setState(() => _isQrScanning = false);
        return;
      }

      Map<String, dynamic> qrDataMap = qrDoc.data() as Map<String, dynamic>;

      if (qrDataMap['isUsed']) {
        _showResultDialog(false, 'QR Code Already Used');
        setState(() => _isQrScanning = false);
        return;
      }

      DateTime expiresAt = DateTime.parse(qrDataMap['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        _showResultDialog(false, 'QR Code Expired');
        setState(() => _isQrScanning = false);
        return;
      }

      await _firestore.collection('visitor_qrs').doc(qrId).update({
        'isUsed': true,
        'usedAt': DateTime.now(),
      });

      await _firestore.collection('gate_entries').add({
        'residentId': qrDataMap['residentId'],
        'residentName': qrDataMap['residentName'],
        'entryType': 'qr_visitor',
        'timestamp': DateTime.now(),
        'status': 'entry',
        'visitorName': qrDataMap['visitorName'],
        'isGuest': true,
        'visitStatus': 'inside',
        'checkInTime': DateTime.now().toIso8601String(),
        'visitingResidentId': qrDataMap['residentId'],
        'visitingResidentName': qrDataMap['residentName'],
      });

      await _openGate();

      _showResultDialog(true, 'Access Granted for ${qrDataMap['visitorName']}');

      setState(() {
        _recentScans.insert(0, {
          'timestamp': DateTime.now(),
          'success': true,
          'message': 'QR: ${qrDataMap['visitorName']} -> ${qrDataMap['residentName']}',
          'type': 'QR',
        });
        if (_recentScans.length > 20) _recentScans.removeLast();
        _isQrScanning = false;
      });
    } catch (e) {
      print('❌ QR processing error: $e');
      _showResultDialog(false, 'Error: $e');
      setState(() => _isQrScanning = false);
    }
  }

  void _showResultDialog(bool success, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: success ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F), size: 48),
        content: Text(message, style: const TextStyle(color: Color(0xFF6B5B4F))),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD4C4A8), backgroundColor: const Color(0xFFF5F0E8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cameraController.dispose();
    super.dispose();
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
            Container(
              color: const Color(0xFF5D4037),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFFF8F0),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFFF8F0),
                unselectedLabelColor: const Color(0xFFD4C4A8),
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code), text: 'SCANNER'),
                  Tab(icon: Icon(Icons.history), text: 'HISTORY'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScannerTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          const Text('Guard Portal', style: TextStyle(fontSize: 12, color: Color(0xFFD4C4A8))),
          const SizedBox(height: 40),
          _buildWebSidebarItem(Icons.edit_document, 'Manual Entry', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.qr_code_scanner, 'QR Scanner', isActive: true, onTap: () {}),
          _buildWebSidebarItem(Icons.exit_to_app, 'Pending Visits', onTap: () => Navigator.pop(context)),
          _buildWebSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.pop(context)),
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
          const Text('QR Scanner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _isScannerConnected ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFFD32F2F).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _isScannerConnected ? const Color(0xFF4CAF50).withOpacity(0.3) : const Color(0xFFD32F2F).withOpacity(0.3))),
                child: Row(children: [Icon(Icons.circle, size: 10, color: _isScannerConnected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)), const SizedBox(width: 6), Text(_isScannerConnected ? 'CONNECTED' : 'DISCONNECTED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isScannerConnected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)))]),
              ),
              const SizedBox(width: 12),
              _headerIconButton(icon: Icons.refresh, tooltip: 'Refresh connection', onTap: _connectToScanner, color: const Color(0xFF8D6E63)),
            ],
          ),
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
        child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Tooltip(message: tooltip, child: Icon(icon, color: color, size: 20))),
      ),
    );
  }

  Widget _buildWebContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                height: 420,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1), width: 2)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null && !_isQrScanning) {
                          _processQRCode(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, size: 32, color: Color(0xFFFFF8F0))),
                    const SizedBox(width: 16),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Scan Visitor QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))), SizedBox(height: 4), Text('Position the QR code within the frame', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63)))])),
                    OutlinedButton.icon(
                      onPressed: _isOpeningGate ? null : _openGate,
                      icon: _isOpeningGate ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.door_front_door, size: 16),
                      label: Text(_isOpeningGate ? 'Opening...' : 'Test Open Gate'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8D6E63), side: const BorderSide(color: Color(0xFFD4C4A8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.history, size: 20, color: Color(0xFF8D6E63)), SizedBox(width: 8), Text('Recent Scans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)))]),
                const SizedBox(height: 16),
                if (_recentScans.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFFF5F0E8), borderRadius: BorderRadius.circular(12)),
                    child: const Column(children: [Icon(Icons.history, size: 40, color: Color(0xFFD4C4A8)), SizedBox(height: 8), Text('No recent scans', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63)))]),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 460),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _recentScans.length,
                      itemBuilder: (context, index) {
                        final scan = _recentScans[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0D5C1))),
                          child: Row(
                            children: [
                              Icon(scan['success'] ? Icons.check_circle : Icons.error, size: 20, color: scan['success'] ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(scan['message'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)), maxLines: 2, overflow: TextOverflow.ellipsis), Text(DateFormat('MMM dd • hh:mm a').format(scan['timestamp'] as DateTime), style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63)))])),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(color: Color(0xFF5D4037), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('QR Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
              GestureDetector(onTap: _connectToScanner, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.refresh, color: Color(0xFFFFF8F0), size: 20))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Visitor Access', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (_isScannerConnected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)).withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: _isScannerConnected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F))), child: Text(_isScannerConnected ? 'ONLINE' : 'OFFLINE', style: TextStyle(fontSize: 10, color: _isScannerConnected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F), fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0D5C1), width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MobileScanner(
                controller: _cameraController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && !_isQrScanning) {
                      _processQRCode(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, -4))]),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)]), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.qr_code_scanner, size: 40, color: Color(0xFFFFF8F0))),
              const SizedBox(height: 12),
              const Text('Scan Visitor QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D4037), letterSpacing: 0.5)),
              const SizedBox(height: 6),
              const Text('Position the QR code within the frame', style: TextStyle(color: Color(0xFF8D6E63), fontSize: 13)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _isScannerConnected ? Colors.green : Colors.red)), const SizedBox(width: 8), Text(_isScannerConnected ? 'Scanner Connected' : 'Scanner Disconnected', style: TextStyle(color: _isScannerConnected ? const Color(0xFF8D6E63) : Colors.red, fontSize: 12, fontWeight: FontWeight.w600))]),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _isOpeningGate ? null : _openGate, icon: _isOpeningGate ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.door_front_door, size: 16), label: Text(_isOpeningGate ? 'Opening...' : 'Test Open Gate'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8D6E63), side: const BorderSide(color: Color(0xFFD4C4A8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_recentScans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.history, size: 70, color: Color(0xFFD4C4A8))),
            const SizedBox(height: 16),
            const Text('No recent scans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF5D4037))),
            const SizedBox(height: 8),
            const Text('Scan a QR code to see activity', style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _recentScans.length,
      itemBuilder: (context, index) {
        final scan = _recentScans[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0D5C1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: scan['success'] ? const Color(0xFF4CAF50).withOpacity(0.12) : const Color(0xFFD32F2F).withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(scan['success'] ? Icons.check_circle_outline : Icons.error_outline, color: scan['success'] ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F), size: 22)),
            title: Text(scan['message'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5D4037))),
            subtitle: Text('${scan['type']} • ${DateFormat('MMM dd, hh:mm a').format(scan['timestamp'])}', style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text(scan['success'] ? '✓' : '✗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scan['success'] ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)))),
          ),
        );
      },
    );
  }
}