import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/gate_provider.dart';
import '../../services/gate_service.dart';
import 'package:intl/intl.dart';

class CameraQRScannerScreen extends StatefulWidget {
  const CameraQRScannerScreen({super.key});

  @override
  State<CameraQRScannerScreen> createState() => _CameraQRScannerScreenState();
}

class _CameraQRScannerScreenState extends State<CameraQRScannerScreen> {
  final GateService _gateService = GateService();
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _scanResult;
  Map<String, dynamic>? _scannedResident;

  @override
  Widget build(BuildContext context) {
    final gateProvider = Provider.of<GateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera QR Scanner'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _isScanning && !_isProcessing
                ? MobileScanner(
              onDetect: (capture) async {
                if (_isProcessing) return;

                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final qrData = barcode.rawValue;
                  if (qrData != null && !_isProcessing) {
                    _isProcessing = true;
                    _isScanning = false;
                    setState(() {});

                    // Show loading
                    setState(() {
                      _scanResult = 'Processing...';
                    });

                    // Validate QR code
                    final result = await _gateService.scanQR(qrData);

                    if (result['success']) {
                      // Get full resident details
                      final resident = await _gateService.getResidentDetails(result['residentId']);

                      setState(() {
                        _scannedResident = resident;
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
                          });
                        }
                      });
                    }
                  }
                }
              },
            )
                : _buildResultScreen(),
          ),

          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Position QR code inside the frame'),
                Text('• Hold steady until scanned'),
                Text('• Resident information will appear automatically'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    if (_scannedResident != null && _scanResult?.contains('Welcome') == true) {
      // SUCCESS - Show resident information
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),

            // Success message
            Text(
              _scanResult ?? 'Access Granted',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Resident Information Card
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

                    _buildInfoRow(
                      'Full Name',
                      _scannedResident?['fullName'] ?? 'N/A',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'House Number',
                      _scannedResident?['houseNumber'] ?? 'N/A',
                      Icons.home_outlined,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'Email',
                      _scannedResident?['email'] ?? 'N/A',
                      Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'Phone Number',
                      _scannedResident?['phoneNumber'] ?? 'Not provided',
                      Icons.phone_outlined,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'RFID Tag',
                      _scannedResident?['rfidTag'] != null
                          ? _scannedResident!['rfidTag']
                          : 'No RFID assigned',
                      Icons.nfc,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'Registered Since',
                      _scannedResident?['createdAt'] != null
                          ? DateFormat('MMMM dd, yyyy').format(_scannedResident!['createdAt'])
                          : 'N/A',
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(
                      'Status',
                      _scannedResident?['isActive'] == true ? 'Active' : 'Inactive',
                      Icons.badge,
                      valueColor: _scannedResident?['isActive'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Auto close message
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
          ],
        ),
      );
    } else if (_scanResult != null) {
      // ERROR - Show error message
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _scanResult!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                    _isScanning = true;
                    _scanResult = null;
                    _scannedResident = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    } else if (_isProcessing) {
      // LOADING
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing QR Code...'),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
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