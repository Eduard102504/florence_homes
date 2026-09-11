import 'package:flutter/material.dart';
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
  String _scannerPort = '8081';  // Changed to HTTP port on Pi
  bool _isScannerConnected = false;

  // QR Scanner
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoGate = prefs.getBool('auto_gate') ?? true;
      _scannerIp = prefs.getString('scanner_ip') ?? '192.168.1.9'; // Change to your Pi's IP
      _scannerPort = prefs.getString('scanner_port') ?? '8081';
    });
  }

  Future<void> _connectToScanner() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_scannerIp:$_scannerPort/status'),
      ).timeout(const Duration(seconds: 3));

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

  Future<void> _openGate() async {
    if (_isOpeningGate) return;

    setState(() {
      _isOpeningGate = true;
    });

    try {
      print('🚪 Opening gate via HTTP to $_scannerIp:$_scannerPort/open');
      final response = await http.post(
        Uri.parse('http://$_scannerIp:$_scannerPort/open'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': 'open'}),
      ).timeout(const Duration(seconds: 5));

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

      // Try alternative method
      try {
        final response = await http.get(
          Uri.parse('http://$_scannerIp:$_scannerPort/open'),
        ).timeout(const Duration(seconds: 3));
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

  Future<void> _processQRCode(String qrData) async {
    if (_isQrScanning) return;

    print('🔍 QR Code detected: $qrData');

    setState(() {
      _isQrScanning = true;
    });

    try {
      // Decode QR data
      Map<String, dynamic> qrInfo;
      try {
        String decoded = utf8.decode(base64.decode(qrData));
        qrInfo = json.decode(decoded);
      } catch (e) {
        qrInfo = json.decode(qrData);
      }

      print('QR Info: $qrInfo');

      String qrId = qrInfo['id'];

      DocumentSnapshot qrDoc = await _firestore
          .collection('visitor_qrs')
          .doc(qrId)
          .get();

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

      // Mark QR as used
      await _firestore.collection('visitor_qrs').doc(qrId).update({
        'isUsed': true,
        'usedAt': DateTime.now(),
      });

      // Record entry
      await _firestore.collection('gate_entries').add({
        'residentId': qrDataMap['residentId'],
        'residentName': qrDataMap['residentName'],
        'entryType': 'qr_visitor',
        'timestamp': DateTime.now(),
        'status': 'entry',
        'visitorName': qrDataMap['visitorName'],
      });

      // OPEN THE GATE
      print('🎫 Opening gate for visitor: ${qrDataMap['visitorName']}');
      await _openGate();

      _showResultDialog(true, 'Access Granted for ${qrDataMap['visitorName']}');

      // Add to recent scans
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
        title: Icon(
          success ? Icons.check_circle_outline : Icons.error_outline,
          color: success ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F),
          size: 48,
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF6B5B4F)),
        ),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD4C4A8),
              backgroundColor: const Color(0xFFF5F0E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            const Text(
              'Gate QR Scanner',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFE0D5C1),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFFF8F0),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFFF8F0),
              unselectedLabelColor: const Color(0xFFE0D5C1),
              tabs: const [
                Tab(icon: Icon(Icons.qr_code), text: 'SCANNER'),
                Tab(icon: Icon(Icons.history), text: 'HISTORY'),
              ],
            ),
          ),
        ),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            // QR Scanner Tab
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE0D5C1),
                        width: 2,
                      ),
                    ),
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4C4A8).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
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
                        child: const Icon(
                          Icons.qr_code_scanner,
                          size: 40,
                          color: Color(0xFFFFF8F0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scan Visitor QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B5B4F),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Position the QR code within the frame',
                        style: TextStyle(
                          color: const Color(0xFFB8A99A),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Scanner status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isScannerConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScannerConnected ? 'Scanner Connected' : 'Scanner Disconnected',
                            style: TextStyle(
                              color: _isScannerConnected ? const Color(0xFF8D6E63) : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Test Gate Button
                      OutlinedButton.icon(
                        onPressed: _isOpeningGate ? null : _openGate,
                        icon: _isOpeningGate
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.door_front_door, size: 16),
                        label: Text(_isOpeningGate ? 'Opening...' : 'Test Open Gate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8D6E63),
                          side: const BorderSide(color: Color(0xFFD4C4A8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Recent Scans Tab
            _recentScans.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4C4A8).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history,
                      size: 70,
                      color: Color(0xFFD4C4A8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent scans',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B5B4F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan a QR code to see activity',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB8A99A),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _recentScans.length,
              itemBuilder: (context, index) {
                final scan = _recentScans[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4C4A8).withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE0D5C1),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scan['success']
                              ? const Color(0xFF8D6E63).withOpacity(0.12)
                              : const Color(0xFFD32F2F).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          scan['success']
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: scan['success']
                              ? const Color(0xFF8D6E63)
                              : const Color(0xFFD32F2F),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        scan['message'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B5B4F),
                        ),
                      ),
                      subtitle: Text(
                        '${scan['type']} • ${DateFormat('MMM dd, hh:mm a').format(scan['timestamp'])}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB8A99A),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scan['success'] ? '✓' : '✗',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scan['success']
                                ? const Color(0xFF8D6E63)
                                : const Color(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}