import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/gate_service.dart';
import '../../providers/gate_provider.dart';
import 'package:intl/intl.dart';

class CameraQRScannerScreen extends StatefulWidget {
  const CameraQRScannerScreen({super.key});

  @override
  State<CameraQRScannerScreen> createState() => _CameraQRScannerScreenState();
}

class _CameraQRScannerScreenState extends State<CameraQRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  final GateService _gateService = GateService();
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _scanResult;
  Map<String, dynamic>? _scannedResident;
  String? _visitorName;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateProvider = Provider.of<GateProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        foregroundColor: const Color(0xFFFFF8F0),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty && !_isProcessing) {
                  _isProcessing = true;
                  _isScanning = false;
                  setState(() {});

                  // Show loading
                  setState(() {
                    _scanResult = 'Processing...';
                  });

                  print("🔴 SCANNED QR: $rawValue");

                  // Validate QR code using GateService
                  final result = await _gateService.scanQR(rawValue);
                  print("📦 SCAN RESULT: $result");

                  if (result['success']) {
                    // Get full resident details
                    final resident = await _gateService.getResidentDetails(result['residentId']);

                    print("👤 RESIDENT: $resident");

                    setState(() {
                      _scannedResident = resident;
                      _visitorName = result['visitorName'];
                      _scanResult = result['message'];
                    });

                    // Refresh gate history
                    await gateProvider.loadRecentEntries();

                    // Auto close after 5 seconds
                    Future.delayed(const Duration(seconds: 5), () {
                      if (mounted) Navigator.pop(context, true);
                    });
                  } else {
                    setState(() {
                      _scanResult = result['message'];
                    });

                    // Reset after 2 seconds
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() {
                          _isProcessing = false;
                          _isScanning = true;
                          _scanResult = null;
                          _scannedResident = null;
                          _visitorName = null;
                        });
                      }
                    });
                  }
                }
              }
            },
          ),

          // QR Scanner overlay frame
          if (_isScanning && !_isProcessing)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 150),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD4C4A8),
                    width: 3,
                  ),
                ),
              ),
            ),

          // Result Screen (Success or Error)
          if (_scanResult != null)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success or Error Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _scannedResident != null && _scanResult?.contains('Welcome') == true
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _scannedResident != null && _scanResult?.contains('Welcome') == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: _scannedResident != null && _scanResult?.contains('Welcome') == true
                              ? Colors.green
                              : Colors.red,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Message
                      Text(
                        _scanResult ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _scannedResident != null && _scanResult?.contains('Welcome') == true
                              ? Colors.green
                              : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Resident Information (if success)
                      if (_scannedResident != null && _scanResult?.contains('Welcome') == true) ...[
                        const SizedBox(height: 24),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.person, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      'Resident Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _buildInfoRow('Full Name', _scannedResident?['fullName'] ?? 'N/A', Icons.person_outline),
                                const SizedBox(height: 12),
                                _buildInfoRow('House Number', _scannedResident?['houseNumber'] ?? 'N/A', Icons.home_outlined),
                                const SizedBox(height: 12),
                                if (_visitorName != null && _visitorName!.isNotEmpty)
                                  _buildInfoRow('Visitor', _visitorName ?? 'N/A', Icons.people_outline),
                                const SizedBox(height: 12),
                                _buildInfoRow('Status', _scannedResident?['isActive'] == true ? 'Active' : 'Inactive', Icons.badge,
                                    valueColor: _scannedResident?['isActive'] == true ? Colors.green : Colors.red),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Closing in 5 seconds...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ] else if (_scanResult != null && _scanResult != 'Processing...') ...[
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isProcessing = false;
                              _isScanning = true;
                              _scanResult = null;
                              _scannedResident = null;
                              _visitorName = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],

                      if (_scanResult == 'Processing...') ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Processing QR Code...'),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Instructions
          if (_isScanning && !_isProcessing)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Position QR code inside the frame',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}