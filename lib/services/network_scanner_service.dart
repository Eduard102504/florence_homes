// lib/services/network_scanner_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkScannerService {
  static final NetworkScannerService _instance = NetworkScannerService._internal();
  factory NetworkScannerService() => _instance;
  NetworkScannerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;

  // ✅ FALLBACK SETTINGS
  String _activeIp = '';
  static const String _ethernetIp = '192.168.1.9';
  static const String _wifiIp = '192.168.1.15';
  int _wsPort = 8082;
  int _httpPort = 8081;

  bool _isConnected = false;

  // ==================== PING HELPER ====================
  /// Pings the Pi's HTTP server on a specific IP to see if it's alive.
  Future<bool> _pingPi(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:$_httpPort/status'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== CONNECT ====================
  Future<bool> connect({String? ip, int? port}) async {
    if (port != null) _wsPort = port;

    // 1. Determine which IP is alive (Ethernet first, then WiFi)
    if (ip != null) {
      _activeIp = ip;
    } else {
      print('🔌 Pinging Ethernet ($_ethernetIp)...');
      if (await _pingPi(_ethernetIp)) {
        _activeIp = _ethernetIp;
        print('✅ Pi found on Ethernet');
      } else {
        print('❌ Ethernet unreachable. Pinging WiFi ($_wifiIp)...');
        if (await _pingPi(_wifiIp)) {
          _activeIp = _wifiIp;
          print('✅ Pi found on WiFi');
        } else {
          print('❌ Pi unreachable on both networks');
          _isConnected = false;
          return false;
        }
      }
    }

    // 2. Connect WebSocket using the active IP
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_activeIp:$_wsPort'),
      );

      _channel!.stream.listen(
            (message) {
          _handleScannedData(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _activeIp = ''; // Force re-ping next time
        },
        onDone: () {
          print('WebSocket disconnected');
          _isConnected = false;
          _activeIp = '';
          _reconnect();
        },
      );

      _channel!.sink.add(json.encode({
        'type': 'handshake',
        'device': 'flutter_app',
        'timestamp': DateTime.now().toIso8601String(),
      }));

      _startHeartbeat();
      _isConnected = true;

      await _firestore.collection('settings').doc('scanner').set({
        'isConnected': true,
        'activeIp': _activeIp,
        'lastSeen': DateTime.now(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
      _activeIp = '';
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        _channel!.sink.add(json.encode({
          'type': 'heartbeat',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    });
  }

  void _handleScannedData(dynamic message) {
    try {
      Map<String, dynamic> data;
      if (message is String) {
        data = json.decode(message);
      } else {
        data = message;
      }

      if (data['type'] == 'rfid_scan') {
        final direction = data['direction'] ?? 'IN';
        final residentName = data['residentName'] ?? 'Resident';
        _notifyScanResult(true, '$direction: $residentName', direction: direction);
      } else if (data['type'] == 'gate_status') {
        _onGateStatus?.call(data['isOpen']);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  // ==================== MANUAL GATE CONTROL ====================
  Future<bool> openGateManually({String? reason, String? operatorName}) async {
    try {
      if (_activeIp.isEmpty) {
        // Try to find it if we don't have it
        if (!await connect()) return false;
      }

      // 1. Send via WebSocket
      if (_channel != null && _isConnected) {
        _channel!.sink.add(json.encode({
          'type': 'open_gate_manual',
          'reason': reason ?? 'Manual override',
          'operator': operatorName ?? 'Admin',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }

      // 2. Send via HTTP as backup
      final response = await http.post(
        Uri.parse('http://$_activeIp:$_httpPort/open'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': 'open_gate_manual',
          'reason': reason ?? 'Manual override',
          'operator': operatorName ?? 'Admin',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      await _firestore.collection('manual_gate_openings').add({
        'reason': reason,
        'operator': operatorName,
        'timestamp': DateTime.now(),
        'source': 'admin_dashboard',
        'ip_used': _activeIp,
      });

      return response.statusCode == 200;
    } catch (e) {
      print('Error opening gate manually: $e');
      return false;
    }
  }

  Future<bool> closeGateManually() async {
    try {
      if (_activeIp.isEmpty && !await connect()) return false;

      if (_channel != null && _isConnected) {
        _channel!.sink.add(json.encode({
          'type': 'close_gate',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }

      final response = await http.post(
        Uri.parse('http://$_activeIp:$_httpPort/manual_down'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'type': 'close_gate'}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> getGateStatus() async {
    try {
      if (_activeIp.isEmpty && !await connect()) return false;

      final response = await http.get(
        Uri.parse('http://$_activeIp:$_httpPort/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return !response.body.contains('OK');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _activeIp = '';
  }

  // ==================== STREAMS ====================
  StreamController<RFIDScanEvent>? _scanResultController;
  Stream<RFIDScanEvent> get scanResults {
    _scanResultController ??= StreamController<RFIDScanEvent>.broadcast();
    return _scanResultController!.stream;
  }

  void _notifyScanResult(bool success, String message, {String direction = 'IN'}) {
    _scanResultController?.add(RFIDScanEvent(
      success: success,
      message: message,
      direction: direction,
      timestamp: DateTime.now(),
    ));
  }

  StreamController<bool>? _gateStatusController;
  Stream<bool> get gateStatus {
    _gateStatusController ??= StreamController<bool>.broadcast();
    return _gateStatusController!.stream;
  }

  void Function(bool)? get _onGateStatus => (isOpen) {
    _gateStatusController?.add(isOpen);
  };
}

class RFIDScanEvent {
  final bool success;
  final String message;
  final String direction;
  final DateTime timestamp;

  RFIDScanEvent({
    required this.success,
    required this.message,
    this.direction = 'IN',
    required this.timestamp,
  });
}