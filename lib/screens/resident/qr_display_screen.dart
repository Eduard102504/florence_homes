import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

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
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.qr_code, size: 22, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'QR for ${widget.visitorName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: _isSharing ? null : _shareQR,
            color: const Color(0xFFFFF8F0),
          ),
        ],
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
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // QR Code Card with RepaintBoundary for capture
                  RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4C4A8).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE0D5C1),
                          width: 1.5,
                        ),
                      ),
                      child: QrImageView(
                        data: widget.qrData,
                        version: QrVersions.auto,
                        size: 250.0,
                        eyeStyle: const QrEyeStyle(
                          color: Color(0xFF5D4037),
                          eyeShape: QrEyeShape.square,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          color: Color(0xFF5D4037),
                          dataModuleShape: QrDataModuleShape.square,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Visitor Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4C4A8).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE0D5C1),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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
                              Icons.person,
                              size: 40,
                              color: Color(0xFFFFF8F0),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.visitorName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8D6E63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Valid for single entry',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8D6E63),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Divider(
                            color: Color(0xFFE0D5C1),
                            height: 24,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.access_time,
                            'Valid Until',
                            '24 hours from generation',
                          ),
                          const SizedBox(height: 8),
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

                  // Share Button only
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _shareQR,
                      icon: _isSharing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)),
                        ),
                      )
                          : const Icon(Icons.share, size: 20),
                      label: Text(_isSharing ? 'Sharing...' : 'Share QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4C4A8),
                        foregroundColor: const Color(0xFF6B5B4F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFE0B2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFFE6A500)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap Share to send this QR code via messaging apps or save to your device.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA87900),
                              height: 1.3,
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
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 10),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB8A99A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B5B4F),
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _captureQR() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      return null;
    } catch (e) {
      print('Error capturing QR: $e');
      return null;
    }
  }

  Future<void> _shareQR() async {
    setState(() => _isSharing = true);

    try {
      final pngBytes = await _captureQR();

      if (pngBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: '🎫 Visitor QR Code for ${widget.visitorName}\n\n🏠 Florence Homes Gate System\nValid for 24 hours only.',
        );
      } else {
        await Share.share(
          '🎫 Visitor QR Code for ${widget.visitorName}\n\n🏠 Florence Homes Gate System\nValid for 24 hours only.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code shared successfully'),
            backgroundColor: Color(0xFF8D6E63),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing QR: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }
}