// lib/screens/guard/gate2_qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../services/tcp_service.dart';

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

  Future<void> _processQR(String rawData) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      Map<String, dynamic> qrInfo = json.decode(utf8.decode(base64.decode(rawData)));
      final qrId = qrInfo['id'];

      final qrDoc = await _firestore.collection('visitor_qrs').doc(qrId).get();
      if (!qrDoc.exists) throw 'Invalid QR';
      final data = qrDoc.data()!;
      if (data['isUsed'] == true) throw 'Already Used';

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Access Granted: ${data['visitorName']}'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _isScanning = false); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: const Color(0xFF5D4037), title: const Text('Gate 2 — QR Scanner')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _processQR(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_isScanning) const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Text('Align QR Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}