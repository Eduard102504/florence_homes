// lib/screens/guard/gate2_qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/tcp_service.dart';
import 'guard_dashboard.dart';
import '../admin/manual_entry_screen.dart';
import '../admin/scanner_management_screen.dart';
import '../admin/pending_visits_screen.dart';
import '../admin/guard_gate_history.dart';
import 'gate2_manual_entry_screen.dart';

class Gate2QrScannerScreen extends StatefulWidget {
  const Gate2QrScannerScreen({super.key});

  @override
  State<Gate2QrScannerScreen> createState() => _Gate2QrScannerScreenState();
}

class _Gate2QrScannerScreenState extends State<Gate2QrScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TCPService _tcpService = TCPService();

  bool _isScanning = false;
  String? _statusMsg;
  Color _statusColor = Colors.green;
  final List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _tcpService.connect();
  }

  void _showStatus(String msg, Color color) {
    if (!mounted) return;
    setState(() { _statusMsg = msg; _statusColor = color; });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _statusMsg == msg) setState(() => _statusMsg = null);
    });
  }

  Future<void> _processQR(String rawData) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      Map<String, dynamic> qrInfo;
      try {
        qrInfo = json.decode(utf8.decode(base64.decode(rawData)));
      } catch (e) {
        qrInfo = json.decode(rawData);
      }

      final qrId = qrInfo['id'];
      final qrDoc = await _firestore.collection('visitor_qrs').doc(qrId).get();

      if (!qrDoc.exists) throw 'Invalid QR Code';
      final data = qrDoc.data()!;
      if (data['isUsed'] == true) throw 'QR Code Already Used';
      final expiresAt = DateTime.parse(data['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) throw 'QR Code Expired';

      await _firestore.collection('visitor_qrs').doc(qrId).update({'isUsed': true, 'usedAt': DateTime.now()});

      await _firestore.collection('gate_entries').add({
        'residentId': data['residentId'],
        'residentName': data['residentName'],
        'visitorName': data['visitorName'],
        'entryType': 'qr_visitor',
        'gate': 'Gate 2',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'entry',
        'isGuest': true,
        'visitStatus': 'inside',
        'checkInTime': DateTime.now().toIso8601String(),
      });

      await _tcpService.openGate2();

      _showStatus('✅ Access Granted: ${data['visitorName']}', Colors.green);

      setState(() {
        _recentScans.insert(0, {'timestamp': DateTime.now(), 'success': true, 'message': 'QR: ${data['visitorName']}', 'type': 'QR'});
        if (_recentScans.length > 20) _recentScans.removeLast();
      });

    } catch (e) {
      _showStatus('❌ $e', Colors.red);
    } finally {
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _isScanning = false); });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 800;

    if (isDesktopWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Row(
          children: [
            _buildWebSidebar(context),
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null && !_isScanning) {
                    _processQR(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
            // Overlay Frame
            Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(20)))),
            // Status Message
            if (_statusMsg != null) Positioned(top: 40, left: 20, right: 20, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _statusColor.withOpacity(0.9), borderRadius: BorderRadius.circular(12)), child: Text(_statusMsg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            if (_isScanning) const Center(child: CircularProgressIndicator(color: Colors.white)),
            // Bottom Nav / Action
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Column(
                children: [
                  const Text('Align QR Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  FloatingActionButton.extended(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: const Color(0xFF5D4037),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Back to Dashboard', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ✅ CORRECT SIDEBAR DESIGN (Same size/colors as Dashboard)
  Widget _buildWebSidebar(BuildContext context) {
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildWebSidebarItem(Icons.dashboard, 'Dashboard', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuardDashboard()))),
                  _buildWebSidebarItem(Icons.edit_document, 'Manual Entry (G1)', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManualEntryScreen()))),
                  _buildWebSidebarItem(Icons.qr_code_scanner, 'QR Scanner (G1)', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScannerManagementScreen()))),
                  _buildWebSidebarItem(Icons.drive_file_rename_outline, 'Manual Entry (G2)', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate2ManualEntryScreen()))),
                  _buildWebSidebarItem(Icons.qr_code_2, 'QR Scanner (G2)', isActive: true, onTap: () {}),
                  _buildWebSidebarItem(Icons.exit_to_app, 'Pending Visits', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PendingVisitsScreen()))),
                  _buildWebSidebarItem(Icons.history, 'Gate History', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuardGateHistory()))),
                ],
              ),
            ),
          ),
          ListTile(leading: const Icon(Icons.logout, color: Color(0xFFD4C4A8)), title: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFFD4C4A8), fontSize: 13)), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuardDashboard()))),
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
          const Text('QR Scanner (Gate 2)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3))),
            child: const Row(children: [Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50)), SizedBox(width: 6), Text('CAMERA READY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)))]),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 500,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1), width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null && !_isScanning) {
                          _processQR(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                  Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(20)))),
                  if (_isScanning) const Center(child: CircularProgressIndicator(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0D5C1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.qr_code_2, color: Color(0xFF8D6E63)), SizedBox(width: 8), Text('Gate 2 QR Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037)))]),
                const SizedBox(height: 16),
                const Text('Position the visitor QR code in the camera frame. Access will log automatically and trigger the Gate 2 servo.', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63), height: 1.5)),
                if (_statusMsg != null) ...[
                  const SizedBox(height: 24),
                  Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _statusColor.withOpacity(0.3))), child: Text(_statusMsg!, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold))),
                ],
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE0D5C1)),
                const SizedBox(height: 16),
                const Text('Recent Scans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5D4037))),
                const SizedBox(height: 12),
                if (_recentScans.isEmpty)
                  const Text('No scans yet', style: TextStyle(fontSize: 12, color: Color(0xFFB8A99A), fontStyle: FontStyle.italic))
                else
                  ..._recentScans.take(5).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(s['success'] ? Icons.check_circle : Icons.error, size: 16, color: s['success'] ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s['message'], style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(DateFormat('hh:mm a').format(s['timestamp']), style: const TextStyle(fontSize: 10, color: Color(0xFFB8A99A))),
                    ]),
                  )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}