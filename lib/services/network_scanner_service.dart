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
  String? _scannerIp;
  int _scannerPort = 8080;
  bool _isConnected = false;

  // Scanner settings from Firebase
  Future<void> loadScannerSettings() async {
    final doc = await _firestore.collection('settings').doc('scanner').get();
    if (doc.exists) {
      _scannerIp = doc.get('ip');
      _scannerPort = doc.get('port') ?? 8080;
      _isConnected = doc.get('isConnected') ?? false;
    }
  }

  // Save scanner settings to Firebase
  Future<void> saveScannerSettings(String ip, int port) async {
    _scannerIp = ip;
    _scannerPort = port;
    await _firestore.collection('settings').doc('scanner').set({
      'ip': ip,
      'port': port,
      'updatedAt': DateTime.now(),
    });
  }

  // Connect to Raspberry Pi scanner
  Future<bool> connect({String? ip, int? port}) async {
    if (ip != null) _scannerIp = ip;
    if (port != null) _scannerPort = port;

    try {
      // First try WebSocket connection
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_scannerIp:$_scannerPort'),
      );

      _channel!.stream.listen(
            (message) {
          _handleScannedData(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('WebSocket disconnected');
          _isConnected = false;
          _reconnect();
        },
      );

      // Send handshake
      _channel!.sink.add(json.encode({
        'type': 'handshake',
        'device': 'flutter_app',
        'timestamp': DateTime.now().toIso8601String(),
      }));

      _startHeartbeat();
      _isConnected = true;

      // Update Firebase
      await _firestore.collection('settings').doc('scanner').update({
        'isConnected': true,
        'lastSeen': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Connection failed: $e');
      _isConnected = false;
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
        String rfidData = data['rfid'];
        _processRFIDScan(rfidData);
      } else if (data['type'] == 'gate_status') {
        _onGateStatus?.call(data['isOpen']);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  Future<void> _processRFIDScan(String rfidData) async {
    try {
      // Check if RFID is registered
      DocumentSnapshot rfidDoc = await _firestore
          .collection('rfid_tags')
          .doc(rfidData)
          .get();

      if (!rfidDoc.exists) {
        _sendToRaspberryPi({
          'type': 'access_denied',
          'rfid': rfidData,
          'reason': 'Unknown RFID',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _notifyScanResult(false, 'Unknown RFID tag');
        return;
      }

      String residentId = rfidDoc.get('residentId');
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(residentId)
          .get();

      if (!residentDoc.exists) {
        _sendToRaspberryPi({
          'type': 'access_denied',
          'rfid': rfidData,
          'reason': 'Resident not found',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _notifyScanResult(false, 'Resident not found');
        return;
      }

      bool isApproved = residentDoc.get('isApproved');
      if (!isApproved) {
        _sendToRaspberryPi({
          'type': 'access_denied',
          'rfid': rfidData,
          'reason': 'Account pending approval',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _notifyScanResult(false, 'Account pending approval');
        return;
      }

      // Check if auto gate open is enabled
      final settings = await _firestore.collection('settings').doc('gate').get();
      bool autoGate = settings.get('autoGate') ?? true;

      if (autoGate) {
        // Send open gate command to Raspberry Pi
        _sendToRaspberryPi({
          'type': 'open_gate',
          'rfid': rfidData,
          'residentId': residentId,
          'residentName': residentDoc.get('fullName'),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Record gate entry
      await _firestore.collection('gate_entries').add({
        'residentId': residentId,
        'residentName': residentDoc.get('fullName'),
        'entryType': 'uhf_rfid',
        'timestamp': DateTime.now(),
        'status': 'entry',
        'rfidTag': rfidData,
      });

      await _firestore.collection('users').doc(residentId).update({
        'lastAccess': DateTime.now(),
      });

      _notifyScanResult(true, 'Access granted for ${residentDoc.get('fullName')}');

    } catch (e) {
      print('Error processing RFID: $e');
      _sendToRaspberryPi({
        'type': 'access_denied',
        'rfid': rfidData,
        'reason': 'System error',
        'timestamp': DateTime.now().toIso8601String(),
      });
      _notifyScanResult(false, 'System error');
    }
  }

  void _sendToRaspberryPi(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(json.encode(data));
    }
  }

  // Manual gate control
  Future<bool> openGateManually({String? reason, String? operatorName}) async {
    try {
      // Send command to Raspberry Pi
      if (_channel != null && _isConnected) {
        _sendToRaspberryPi({
          'type': 'open_gate_manual',
          'reason': reason ?? 'Manual override',
          'operator': operatorName ?? 'Admin',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Also send HTTP request as backup
      final response = await http.post(
        Uri.parse('http://$_scannerIp:$_scannerPort/open'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': 'open_gate_manual',
          'reason': reason ?? 'Manual override',
          'operator': operatorName ?? 'Admin',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      // Log manual gate opening
      await _firestore.collection('manual_gate_openings').add({
        'reason': reason,
        'operator': operatorName,
        'timestamp': DateTime.now(),
        'source': 'admin_dashboard',
      });

      return response.statusCode == 200;
    } catch (e) {
      print('Error opening gate manually: $e');
      return false;
    }
  }

  Future<bool> closeGateManually() async {
    try {
      if (_channel != null && _isConnected) {
        _sendToRaspberryPi({
          'type': 'close_gate',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      final response = await http.post(
        Uri.parse('http://$_scannerIp:$_scannerPort/close'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'type': 'close_gate'}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error closing gate: $e');
      return false;
    }
  }

  Future<bool> getGateStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_scannerIp:$_scannerPort/status'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isOpen'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  StreamController<RFIDScanEvent>? _scanResultController;
  Stream<RFIDScanEvent> get scanResults {
    _scanResultController ??= StreamController<RFIDScanEvent>.broadcast();
    return _scanResultController!.stream;
  }

  void _notifyScanResult(bool success, String message) {
    _scanResultController?.add(RFIDScanEvent(
      success: success,
      message: message,
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
  final DateTime timestamp;

  RFIDScanEvent({
    required this.success,
    required this.message,
    required this.timestamp,
  });
}