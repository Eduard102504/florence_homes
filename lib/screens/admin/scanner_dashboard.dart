import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/unified_scanner_service.dart';
import 'camera_qr_scanner_screen.dart';

class ScannerDashboard extends StatefulWidget {
  const ScannerDashboard({super.key});

  @override
  State<ScannerDashboard> createState() => _ScannerDashboardState();
}

class _ScannerDashboardState extends State<ScannerDashboard> {
  final UnifiedScannerService _scannerService = UnifiedScannerService.instance;
  List<RFIDScanEvent> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _scannerService.scanEvents.listen((event) {
      setState(() {
        _recentScans.insert(0, event);
        if (_recentScans.length > 50) _recentScans.removeLast();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scanner Monitor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF5D4037), // Dark Brown
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF8F0), // Warm cream
              const Color(0xFFEFEBE9), // Light brownish cream
            ],
          ),
        ),
        child: Column(
          children: [
            // Scanner Status Cards
            Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Camera QR Scanner Card (CLICKABLE)
                  _buildClickableScannerCard(
                    title: 'Camera QR',
                    icon: Icons.qr_code_scanner,
                    color: const Color(0xFF9C27B0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CameraQRScannerScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildStatusCard('Bluetooth', Icons.bluetooth, const Color(0xFF5D4037), true),
                  const SizedBox(width: 12),
                  _buildStatusCard('USB', Icons.usb, const Color(0xFF8D6E63), false),
                  const SizedBox(width: 12),
                  _buildStatusCard('Network', Icons.wifi, const Color(0xFF6D4C41), true),
                  const SizedBox(width: 12),
                  _buildStatusCard('Phone NFC', Icons.nfc, const Color(0xFFA0522D), true),
                ],
              ),
            ),

            // Recent Scans
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.history, color: Color(0xFF5D4037), size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Recent Scans',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _recentScans.isEmpty
                        ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.scanner, size: 80, color: Color(0xFFD7CCC8)),
                          SizedBox(height: 16),
                          Text(
                            'No scans yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF8D6E63),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Scan RFID tags or QR codes to see activity',
                            style: TextStyle(color: Color(0xFFBCAAA4)),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _recentScans.length,
                      itemBuilder: (context, index) {
                        final scan = _recentScans[index];
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: const Color(0xFFFFF8F0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD7CCC8),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _getScannerColor(scan.source),
                                      _getScannerColor(scan.source).withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: _getScannerIcon(scan.source),
                              ),
                              title: Text(
                                scan.resident?['name'] ?? 'Unknown RFID',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getScannerName(scan.source)} • ${_formatTime(scan.timestamp)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8D6E63),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scan.success
                                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                                      : const Color(0xFFD32F2F).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: scan.success
                                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                                        : const Color(0xFFD32F2F).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  scan.success ? 'Granted' : 'Denied',
                                  style: TextStyle(
                                    color: scan.success
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFD32F2F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, IconData icon, Color color, bool connected) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: connected
              ? [color.withOpacity(0.15), color.withOpacity(0.05)]
              : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: connected
            ? [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: connected ? color : Colors.grey,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: connected ? color : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
              boxShadow: connected
                  ? [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableScannerCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getScannerIcon(ScannerSource source) {
    switch (source) {
      case ScannerSource.bluetooth:
        return const Icon(Icons.bluetooth, color: Color(0xFF5D4037), size: 24);
      case ScannerSource.usb:
        return const Icon(Icons.usb, color: Color(0xFF8D6E63), size: 24);
      case ScannerSource.network:
        return const Icon(Icons.wifi, color: Color(0xFF6D4C41), size: 24);
      case ScannerSource.nfc:
        return const Icon(Icons.nfc, color: Color(0xFFA0522D), size: 24);
    }
  }

  Color _getScannerColor(ScannerSource source) {
    switch (source) {
      case ScannerSource.bluetooth:
        return const Color(0xFF5D4037);
      case ScannerSource.usb:
        return const Color(0xFF8D6E63);
      case ScannerSource.network:
        return const Color(0xFF6D4C41);
      case ScannerSource.nfc:
        return const Color(0xFFA0522D);
    }
  }

  String _getScannerName(ScannerSource source) {
    switch (source) {
      case ScannerSource.bluetooth:
        return 'Bluetooth';
      case ScannerSource.usb:
        return 'USB';
      case ScannerSource.network:
        return 'Network';
      case ScannerSource.nfc:
        return 'NFC';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}