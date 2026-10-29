// lib/screens/admin/qr_display_screen.dart
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

  const QRDisplayScreen({super.key, required this.qrData, required this.visitorName, this.isSavedQR = false});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

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
            Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20), child: _buildContent())),
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
      child: ListTile(onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), tileColor: isActive ? const Color(0xFFD4C4A8).withOpacity(0.15) : Colors.transparent, leading: Icon(icon, color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8)), title: Text(title, style: TextStyle(color: isActive ? const Color(0xFFFFF8F0) : const Color(0xFFD4C4A8), fontWeight: isActive ? FontWeight.bold : FontWeight.normal))),
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
          Expanded(child: Text('QR for ${widget.visitorName}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)), overflow: TextOverflow.ellipsis, maxLines: 1)),
          _headerIconButton(icon: Icons.share, tooltip: 'Share QR', onTap: _isSharing ? () {} : _shareQR, showSpinner: _isSharing, color: const Color(0xFF8D6E63)),
        ],
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap, bool showSpinner = false, Color color = const Color(0xFF5D4037)}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Tooltip(message: tooltip, child: showSpinner ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(color))) : Icon(icon, color: color, size: 20)),
        ),
      ),
    );
  }

  Widget _buildWebContent() {
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _buildContent()));
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
                  Row(children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Color(0xFFFFF8F0), size: 20))), const SizedBox(width: 12), const Text('QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFFFF8F0), letterSpacing: 1))]),
                  GestureDetector(onTap: _isSharing ? null : _shareQR, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: _isSharing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)))) : const Icon(Icons.share, color: Color(0xFFFFF8F0), size: 20))),
                ],
              ),
              const SizedBox(height: 24),
              Text(widget.visitorName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFF8F0)), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF5D4037).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))], border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5)),
            child: QrImageView(data: widget.qrData, version: QrVersions.auto, size: 250.0, eyeStyle: const QrEyeStyle(color: Color(0xFF5D4037), eyeShape: QrEyeShape.square), dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF5D4037), dataModuleShape: QrDataModuleShape.square)),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF8D6E63)]), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.person, size: 40, color: Color(0xFFFFF8F0))),
                const SizedBox(height: 12),
                Text(widget.visitorName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037), letterSpacing: 0.5), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: const Text('Valid for single entry', style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), fontWeight: FontWeight.w500))),
                const Divider(color: Color(0xFFE0D5C1), height: 24),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Valid Until', '24 hours from generation'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.qr_code, 'Instructions', 'Show this QR code to security guard at gate'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareQR,
            icon: _isSharing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFF8F0)))) : const Icon(Icons.share, size: 20),
            label: Text(_isSharing ? 'Sharing...' : 'Share QR Code'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFFFF8F0), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFE0B2), width: 1)),
          child: Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: Color(0xFFE6A500)),
              SizedBox(width: 10),
              Expanded(child: Text('Tap Share to send this QR code via messaging apps or save to your device.', style: TextStyle(fontSize: 11, color: Color(0xFFA87900), height: 1.3))),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD4C4A8)),
        const SizedBox(width: 10),
        SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Future<Uint8List?> _captureQR() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) return byteData.buffer.asUint8List();
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
        await Share.shareXFiles([XFile(filePath)], text: '🎫 Visitor QR Code for ${widget.visitorName}\n\n🏠 Florence Homes Gate System\nValid for 24 hours only.');
      } else {
        await Share.share('🎫 Visitor QR Code for ${widget.visitorName}\n\n🏠 Florence Homes Gate System\nValid for 24 hours only.');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code shared successfully'), backgroundColor: Color(0xFF8D6E63), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing QR: $e'), backgroundColor: const Color(0xFFD32F2F), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}