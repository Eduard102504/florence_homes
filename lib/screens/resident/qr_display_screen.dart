import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  final double contentMaxWidth = kIsWeb ? 900 : double.infinity;
  final double outerPadding = kIsWeb ? 24 : 20;

  // ============================================================
  // INLINE HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFD4C4A8),
      padding: EdgeInsets.fromLTRB(
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
        kIsWeb ? 20 : 16,
        kIsWeb ? 14 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _iconPill(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _iconPill(
                  icon: Icons.share,
                  tooltip: 'Share QR',
                  onTap: _isSharing ? () {} : _shareQR,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code,
                  size: 26, color: Color(0xFFFFF8F0)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'QR for ${widget.visitorName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 22,
                    color: Color(0xFFFFF8F0),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconPill({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFF8F0).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: const Color(0xFFFFF8F0), size: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4C4A8),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFF5F0E8),
              Color(0xFFEDE5D8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(outerPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(maxWidth: contentMaxWidth),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // QR Card
                          RepaintBoundary(
                            key: _repaintKey,
                            child: Container(
                              padding: EdgeInsets.all(kIsWeb ? 16 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4C4A8)
                                        .withOpacity(0.3),
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
                                size: kIsWeb ? 200.0 : 250.0,
                                eyeStyle: const QrEyeStyle(
                                  color: Color(0xFF5D4037),
                                  eyeShape: QrEyeShape.square,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  color: Color(0xFF5D4037),
                                  dataModuleShape:
                                  QrDataModuleShape.square,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: kIsWeb ? 18 : 24),

                          // Visitor Info Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4C4A8)
                                      .withOpacity(0.15),
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
                              padding: EdgeInsets.all(kIsWeb ? 16 : 20),
                              child: Column(
                                children: [
                                  Container(
                                    padding:
                                    EdgeInsets.all(kIsWeb ? 10 : 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFD4C4A8),
                                          Color(0xFFC4A882)
                                        ],
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: kIsWeb ? 32 : 40,
                                      color: const Color(0xFFFFF8F0),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.visitorName,
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF5D4037),
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8D6E63)
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(20),
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

                          SizedBox(height: kIsWeb ? 18 : 24),

                          // Share Button
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
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFF8F0)),
                                ),
                              )
                                  : const Icon(Icons.share, size: 20),
                              label: Text(_isSharing
                                  ? 'Sharing...'
                                  : 'Share QR Code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4C4A8),
                                foregroundColor: const Color(0xFF6B5B4F),
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
                              children: const [
                                Icon(Icons.info_outline,
                                    size: 16, color: Color(0xFFE6A500)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tap Share to send this QR code via messaging apps or save to your device.',
                                    style: TextStyle(
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
            ],
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
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B5B4F)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _captureQR() async {
    try {
      RenderRepaintBoundary boundary =
      _repaintKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);

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
        final filePath =
            '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          text:
          '🎫 Visitor QR Code for ${widget.visitorName}\n\n🏠 Florence Homes Gate System\nValid for 24 hours only.',
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
      if (mounted) setState(() => _isSharing = false);
    }
  }
}