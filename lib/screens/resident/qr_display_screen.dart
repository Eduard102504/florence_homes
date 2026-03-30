import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/qr_service.dart';

class QRDisplayScreen extends StatefulWidget {
  final String qrData;
  final String visitorName;
  final bool isSavedQR;

  const QRDisplayScreen({
    super.key,
    required this.qrData,
    required this.visitorName,
    this.isSavedQR = false,
  });

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  final QRService _qrService = QRService();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code for ${widget.visitorName}'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareQR,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _saveQR,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: 250.0,
                  eyeStyle: const QrEyeStyle(
                    color: Colors.black,
                    eyeShape: QrEyeShape.square,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    color: Colors.black,
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Visitor Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 48,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.visitorName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Valid for single entry',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.access_time,
                        'Valid Until',
                        '24 hours from generation',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.qr_code,
                        'Instructions',
                        'Show this QR code to security guard at gate',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _shareQR,
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveQR,
                      icon: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.download),
                      label: Text(_isSaving ? 'Saving...' : 'Save to Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: This QR code is valid for 24 hours only. Please share it only with your intended visitor.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _shareQR() async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';

      // Create a simple widget to capture QR code
      final repaintBoundary = RepaintBoundary(
        child: QrImageView(
          data: widget.qrData,
          version: QrVersions.auto,
          size: 300.0,
        ),
      );

      // You would need to capture the widget to an image
      // For now, share the QR data as text
      await Share.share(
        'Visitor QR Code for ${widget.visitorName}\nData: ${widget.qrData}\n\nFlorence Homes Gate System',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR: $e')),
        );
      }
    }
  }

  Future<void> _saveQR() async {
    setState(() => _isSaving = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'qr_${widget.visitorName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final filePath = '${directory.path}/$fileName';

      await File(filePath).writeAsString(widget.qrData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR data saved to ${directory.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving QR: $e')),
        );
      }
    }

    setState(() => _isSaving = false);
  }
}