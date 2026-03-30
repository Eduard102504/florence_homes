import 'package:flutter/material.dart';
import '../../services/unified_scanner_service.dart';

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
        title: const Text('Scanner Monitor'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Scanner Status Cards
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildStatusCard('Bluetooth', Icons.bluetooth, Colors.blue, true),
                const SizedBox(width: 12),
                _buildStatusCard('USB', Icons.usb, Colors.orange, false),
                const SizedBox(width: 12),
                _buildStatusCard('Network', Icons.wifi, Colors.teal, true),
                const SizedBox(width: 12),
                _buildStatusCard('Phone NFC', Icons.nfc, Colors.purple, true),
              ],
            ),
          ),

          // Recent Scans
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent Scans',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = _recentScans[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: _getScannerIcon(scan.source),
                          title: Text(scan.resident?['name'] ?? 'Unknown RFID'),
                          subtitle: Text(
                            '${scan.source.toString().split('.').last} • ${_formatTime(scan.timestamp)}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: scan.success ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              scan.success ? 'Granted' : 'Denied',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
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
    );
  }

  Widget _buildStatusCard(String title, IconData icon, Color color, bool connected) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: connected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? color : Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: connected ? color : Colors.grey, size: 32),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: connected ? color : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Icon _getScannerIcon(ScannerSource source) {
    switch (source) {
      case ScannerSource.bluetooth:
        return const Icon(Icons.bluetooth, color: Colors.blue);
      case ScannerSource.usb:
        return const Icon(Icons.usb, color: Colors.orange);
      case ScannerSource.network:
        return const Icon(Icons.wifi, color: Colors.teal);
      case ScannerSource.nfc:
        return const Icon(Icons.nfc, color: Colors.purple);
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