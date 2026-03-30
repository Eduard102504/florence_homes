import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class NetworkScannerService {
  static NetworkScannerService? _instance;
  static NetworkScannerService get instance {
    _instance ??= NetworkScannerService._internal();
    return _instance!;
  }

  NetworkScannerService._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  String? _currentScannerIp;

  Future<bool> connectWebSocket(String ip, int port) async {
    try {
      _currentScannerIp = ip;
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$ip:$port'),
      );

      _channel!.stream.listen(
            (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _reconnect();
        },
        onDone: () {
          _reconnect();
        },
      );

      _channel!.sink.add(json.encode({
        'type': 'handshake',
        'device': 'android_app',
        'version': '1.0',
      }));

      _startHeartbeat();

      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      Map<String, dynamic> data = json.decode(message);

      if (data['type'] == 'rfid_scan') {
        String rfidData = data['rfid'];
        _rfidStreamController.add(rfidData);
      }
    } catch (e) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        _channel!.sink.add(json.encode({
          'type': 'heartbeat',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    });
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentScannerIp != null) {
        connectWebSocket(_currentScannerIp!, 8080);
      }
    });
  }

  final StreamController<String> _rfidStreamController =
  StreamController<String>.broadcast();
  Stream<String> get rfidDataStream => _rfidStreamController.stream;

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
  }
}