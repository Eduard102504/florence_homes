import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/background_nfc_service.dart';
import 'package:intl/intl.dart';
import 'camera_qr_scanner_screen.dart';

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
          result['success'] ? Icons.check_circle_outline : Icons.error_outline,
          color: result['success'] ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F),
          size: 40,
        ),
        backgroundColor: const Color(0xFFFFF8F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0D5C1), width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result['success']) ...[
              const Text('🎉 Access Granted!', style: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _buildCuteInfoRow('👤', 'Resident', result['residentName']),
              _buildCuteInfoRow('🏠', 'House', result['houseNumber']),
            ] else ...[
              const Text('😔 Access Denied', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _buildCuteInfoRow('❌', 'Reason', result['message']),
            ],
            const Divider(color: Color(0xFFE0D5C1), height: 16),
            _buildCuteInfoRow('🔖', 'Tag', result['tagId']),
            _buildCuteInfoRow('⏰', 'Time', DateFormat('hh:mm:ss a').format(DateTime.now())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8D6E63),
              backgroundColor: const Color(0xFFF5F0E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCuteInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFB8A99A), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5B4F), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.scanner, size: 24, color: Color(0xFFFFF8F0)),
            const SizedBox(width: 10),
            const Text(
              'Scanner Management',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD4C4A8),
        elevation: 0,
        actions: [
          if (_nfcScanning)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF8D6E63).withOpacity(0.3), blurRadius: 4)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFFFFF8F0)),
                  SizedBox(width: 4),
                  Text('SCANNING', style: TextStyle(color: Color(0xFFFFF8F0), fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NFC Scanner Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                    ),
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
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.nfc, color: Color(0xFFFFF8F0), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('📱 Phone NFC Scanner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _nfcScanning ? const Color(0xFF8D6E63).withOpacity(0.15) : const Color(0xFFD4C4A8).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_nfcScanning ? Icons.power_settings_new : Icons.power_off, size: 10, color: _nfcScanning ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A)),
                                          const SizedBox(width: 2),
                                          Text(_nfcScanning ? 'Active' : 'Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _nfcScanning ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.scale(
                                scale: 1.0,
                                child: Switch(
                                  value: _nfcScanning,
                                  onChanged: (value) => value ? _startNFCScanning() : _stopNFCScanning(),
                                  activeColor: const Color(0xFF8D6E63),
                                  activeTrackColor: const Color(0xFFD4C4A8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8D6E63).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD4C4A8).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Text('💡', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(child: Text('NFC runs in background! Tap RFID tag to grant access.', style: TextStyle(fontSize: 11, color: const Color(0xFF8D6E63), fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Recent Scans
                if (_recentScans.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.history, color: Color(0xFF8D6E63), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text('Recent Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                        child: Text('${_recentScans.length} scans', style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentScans.length > 3 ? 3 : _recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = _recentScans[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 1))],
                        ),
                        child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0D5C1), width: 1)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: scan['success'] ? const Color(0xFF8D6E63).withOpacity(0.12) : const Color(0xFFD32F2F).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(scan['success'] ? Icons.check_circle_outline : Icons.error_outline, color: scan['success'] ? const Color(0xFF8D6E63) : const Color(0xFFD32F2F), size: 18),
                            ),
                            title: Text(scan['success'] ? scan['residentName'] ?? 'Unknown' : scan['message'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: scan['success'] ? const Color(0xFF6B5B4F) : const Color(0xFFD32F2F))),
                            subtitle: Text(scan['tagId']?.substring(0, 10) ?? 'No tag', style: const TextStyle(fontSize: 10, color: Color(0xFFB8A99A))),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF5F0E8), borderRadius: BorderRadius.circular(16)),
                              child: Text(DateFormat('hh:mm a').format(scan['timestamp']), style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // External Scanners Title
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFD4C4A8).withOpacity(0.3), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.devices, color: Color(0xFF8D6E63), size: 18)),
                    const SizedBox(width: 8),
                    const Text('External Scanners', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                  ],
                ),
                const SizedBox(height: 20),

                // CAMERA QR SCANNER - MANUAL ADD (SURE NA LALABAS)
                GestureDetector(
                  onTap: () async {
                    print("🎯 CAMERA QR SCANNER TAPPED!");
                    final result = await Navigator.pushNamed(
                      context,
                      '/qr_scanner',
                    );
                    if (result != null) {
                      print("✅ SCAN RESULT: $result");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR Code scanned successfully!'),
                          backgroundColor: Color(0xFF8D6E63),
                        ),
                      );
                      setState(() {});
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camera QR Scanner',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap to scan visitor QR codes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Bluetooth Scanner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 6)],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFF8D6E63), const Color(0xFF8D6E63).withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Text('🔷', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 2),
                                Icon(Icons.bluetooth, color: Color(0xFFFFF8F0), size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bluetooth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                                const Text('Wireless RFID scanners', style: TextStyle(fontSize: 10, color: Color(0xFFB8A99A))),
                                Text(_bluetoothEnabled ? '✓ Ready' : '○ Disabled', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _bluetoothEnabled ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A))),
                              ],
                            ),
                          ),
                          Switch(
                            value: _bluetoothEnabled,
                            onChanged: (v) async {
                              setState(() => _bluetoothEnabled = v);
                              await _saveSetting('bt_scanner', v);
                            },
                            activeColor: const Color(0xFF8D6E63),
                            activeTrackColor: const Color(0xFFD4C4A8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // USB Scanner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 6)],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFFB8A99A), const Color(0xFFB8A99A).withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Text('🔌', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 2),
                                Icon(Icons.usb, color: Color(0xFFFFF8F0), size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('USB Scanner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F))),
                                const Text('USB-OTG connection', style: TextStyle(fontSize: 10, color: Color(0xFFB8A99A))),
                                Text(_usbEnabled ? '✓ Waiting' : '○ Disabled', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _usbEnabled ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A))),
                              ],
                            ),
                          ),
                          Switch(
                            value: _usbEnabled,
                            onChanged: (v) async {
                              setState(() => _usbEnabled = v);
                              await _saveSetting('usb_scanner', v);
                            },
                            activeColor: const Color(0xFF8D6E63),
                            activeTrackColor: const Color(0xFFD4C4A8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Network Scanner
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 6)],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                    ),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.wifi, color: Color(0xFFFFF8F0), size: 20),
                      ),
                      title: const Text('🌐 Network Scanner', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F), fontSize: 13)),
                      subtitle: Text(
                        _networkEnabled ? '✓ Connected to $_networkIp' : '○ Disabled',
                        style: TextStyle(color: _networkEnabled ? const Color(0xFF8D6E63) : const Color(0xFFB8A99A), fontSize: 10),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Enable', style: TextStyle(color: Color(0xFF6B5B4F), fontSize: 12)),
                                value: _networkEnabled,
                                onChanged: (v) async {
                                  setState(() => _networkEnabled = v);
                                  await _saveSetting('net_scanner', v);
                                },
                                activeColor: const Color(0xFF8D6E63),
                              ),
                              if (_networkEnabled) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  decoration: InputDecoration(
                                    labelText: 'IP Address',
                                    labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFFFF8F0),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => _networkIp = v,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Port',
                                    labelStyle: const TextStyle(color: Color(0xFFB8A99A), fontSize: 11),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFFFF8F0),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _networkPort = v,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    if (_networkIp != null) {
                                      await _saveSetting('network_ip', _networkIp);
                                      await _saveSetting('network_port', _networkPort);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Connecting...'),
                                          backgroundColor: Color(0xFF8D6E63),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.link, size: 14),
                                  label: const Text('Connect', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4C4A8),
                                    foregroundColor: const Color(0xFF6B5B4F),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Auto Gate Control
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4C4A8).withOpacity(0.15), blurRadius: 6)],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE0D5C1), width: 1.5),
                    ),
                    child: SwitchListTile(
                      title: const Text('🚪 Auto Gate Control', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B5B4F), fontSize: 13)),
                      subtitle: const Text('Auto-open gate on success', style: TextStyle(color: Color(0xFFB8A99A), fontSize: 11)),
                      value: _autoGate,
                      onChanged: (v) async {
                        setState(() => _autoGate = v);
                        await _saveSetting('auto_gate', v);
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFD4C4A8), Color(0xFFC4A882)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.door_front_door, color: _autoGate ? const Color(0xFFFFF8F0) : const Color(0xFFE0D5C1), size: 20),
                      ),
                      activeColor: const Color(0xFF8D6E63),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}