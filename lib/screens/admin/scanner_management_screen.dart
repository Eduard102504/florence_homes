import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/background_nfc_service.dart';
import 'package:intl/intl.dart';
class ScannerManagementScreen extends StatefulWidget {
  const ScannerManagementScreen({super.key});

  @override
  State<ScannerManagementScreen> createState() => _ScannerManagementScreenState();
}

class _ScannerManagementScreenState extends State<ScannerManagementScreen> {
  bool _bluetoothEnabled = false;
  bool _usbEnabled = false;
  bool _networkEnabled = false;
  bool _autoGate = false;
  bool _nfcScanning = false;
  String? _networkIp;
  String _networkPort = '8080';

  final BackgroundNFCService _nfcService = BackgroundNFCService();
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNFCStatus();
  }

  void _checkNFCStatus() {
    setState(() {
      _nfcScanning = _nfcService.isScanning;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bluetoothEnabled = prefs.getBool('bt_scanner') ?? false;
      _usbEnabled = prefs.getBool('usb_scanner') ?? false;
      _networkEnabled = prefs.getBool('net_scanner') ?? false;
      _autoGate = prefs.getBool('auto_gate') ?? false;
      _networkIp = prefs.getString('network_ip');
      _networkPort = prefs.getString('network_port') ?? '8080';
      _nfcScanning = prefs.getBool('nfc_scanning') ?? false;
    });

    // If NFC was previously on, restart it
    if (_nfcScanning) {
      _startNFCScanning();
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _startNFCScanning() {
    setState(() {
      _nfcScanning = true;
    });
    _saveSetting('nfc_scanning', true);

    _nfcService.startScanning((result) {
      setState(() {
        _recentScans.insert(0, {
          'timestamp': DateTime.now(),
          'success': result['success'],
          'residentName': result['residentName'],
          'houseNumber': result['houseNumber'],
          'message': result['message'],
          'tagId': result['tagId'],
        });
        if (_recentScans.length > 20) _recentScans.removeLast();
      });

      // Show notification
      _showScanResult(result);
    });
  }

  void _stopNFCScanning() {
    setState(() {
      _nfcScanning = false;
    });
    _saveSetting('nfc_scanning', false);
    _nfcService.stopScanning();
  }

  void _showScanResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Icon(
          result['success'] ? Icons.check_circle : Icons.error,
          color: result['success'] ? Colors.green : Colors.red,
          size: 48,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result['success']) ...[
              Text('✅ ${result['message']}'),
              const SizedBox(height: 8),
              Text('Resident: ${result['residentName']}'),
              Text('House: ${result['houseNumber']}'),
            ] else ...[
              Text('❌ ${result['message']}'),
            ],
            const SizedBox(height: 8),
            Text('Tag: ${result['tagId']}'),
            const SizedBox(height: 8),
            Text('Time: ${DateFormat('hh:mm:ss a').format(DateTime.now())}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Don't stop scanning on dispose - keep running in background
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Management'),
        backgroundColor: Colors.green,
        actions: [
          if (_nfcScanning)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text('SCANNING', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NFC Scanner Card with ON/OFF toggle
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.nfc, color: Colors.purple, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone NFC Scanner',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _nfcScanning
                                    ? '🔴 NFC Scanning ACTIVE - Running in background'
                                    : '⚪ NFC Scanning OFF',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _nfcScanning ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _nfcScanning,
                          onChanged: (value) {
                            if (value) {
                              _startNFCScanning();
                            } else {
                              _stopNFCScanning();
                            }
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'NFC scanner runs in background. You can navigate to other screens and it will continue scanning.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent Scans
            if (_recentScans.isNotEmpty) ...[
              const Text(
                'Recent Scans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentScans.length > 5 ? 5 : _recentScans.length,
                itemBuilder: (context, index) {
                  final scan = _recentScans[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        scan['success'] ? Icons.check_circle : Icons.error,
                        color: scan['success'] ? Colors.green : Colors.red,
                      ),
                      title: Text(scan['success'] ? scan['residentName'] ?? 'Unknown' : scan['message']),
                      subtitle: Text(scan['tagId'] ?? 'No tag'),
                      trailing: Text(
                        DateFormat('hh:mm a').format(scan['timestamp']),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

            // Other Scanner Types (UI only)
            const Text(
              'External Scanners',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Bluetooth Scanner
            _buildScannerCard(
              title: 'Bluetooth Scanner',
              icon: Icons.bluetooth,
              color: Colors.blue,
              enabled: _bluetoothEnabled,
              onChanged: (value) async {
                setState(() => _bluetoothEnabled = value);
                await _saveSetting('bt_scanner', value);
              },
              subtitle: 'Connect wireless RFID scanners',
              status: _bluetoothEnabled ? 'Ready to connect' : 'Disabled',
            ),

            const SizedBox(height: 12),

            // USB Scanner
            _buildScannerCard(
              title: 'USB Scanner',
              icon: Icons.usb,
              color: Colors.orange,
              enabled: _usbEnabled,
              onChanged: (value) async {
                setState(() => _usbEnabled = value);
                await _saveSetting('usb_scanner', value);
              },
              subtitle: 'Connect via USB-OTG cable',
              status: _usbEnabled ? 'Waiting for device' : 'Disabled',
            ),

            const SizedBox(height: 12),

            // Network Scanner
            Card(
              elevation: 2,
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wifi, color: Colors.teal, size: 30),
                ),
                title: const Text(
                  'Network Scanner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _networkEnabled ? 'Connected to $_networkIp' : 'Disabled',
                  style: TextStyle(
                    color: _networkEnabled ? Colors.green : Colors.grey,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Network Scanner'),
                          value: _networkEnabled,
                          onChanged: (value) async {
                            setState(() => _networkEnabled = value);
                            await _saveSetting('net_scanner', value);
                          },
                        ),
                        if (_networkEnabled) ...[
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Scanner IP Address',
                              border: OutlineInputBorder(),
                              hintText: '192.168.1.100',
                            ),
                            onChanged: (value) => _networkIp = value,
                            controller: TextEditingController(text: _networkIp),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _networkPort = value,
                            controller: TextEditingController(text: _networkPort),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_networkIp != null) {
                                await _saveSetting('network_ip', _networkIp);
                                await _saveSetting('network_port', _networkPort);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Connecting to network scanner...')),
                                );
                              }
                            },
                            child: const Text('Connect'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Auto Gate Control
            Card(
              child: SwitchListTile(
                title: const Text('Auto Gate Control'),
                subtitle: const Text('Automatically open gate on successful scan'),
                value: _autoGate,
                onChanged: (value) async {
                  setState(() => _autoGate = value);
                  await _saveSetting('auto_gate', value);
                },
                secondary: Icon(
                  Icons.door_front_door,
                  color: _autoGate ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool enabled,
    required Function(bool)? onChanged,
    required String subtitle,
    required String status,
    bool showSwitch = true,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (showSwitch)
              Switch(
                value: enabled,
                onChanged: onChanged,
                activeColor: color,
              ),
          ],
        ),
      ),
    );
  }
}