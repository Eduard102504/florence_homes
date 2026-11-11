// lib/services/tcp_service.dart
import 'dart:io';
import 'dart:async';

class TCPService {
  static final TCPService _instance = TCPService._internal();
  factory TCPService() => _instance;
  TCPService._internal();

  Socket? _socket;
  bool _isConnected = false;

  String _activeIp = '';
  static const String _ethernetIp = '192.168.1.9';
  static const String _wifiIp = '192.168.1.15';
  int _port = 8080;

  StreamSubscription<List<int>>? _subscription;

  bool get isConnected => _isConnected;
  String get activeIp => _activeIp;

  void setPort(int port) => _port = port;

  Future<bool> connect() async {
    try {
      final oldSub = _subscription;
      _subscription = null;
      if (oldSub != null) await oldSub.cancel();

      final oldSocket = _socket;
      _socket = null;
      if (oldSocket != null) {
        try { await oldSocket.close(); } catch (_) {}
        try { oldSocket.destroy(); } catch (_) {}
      }

      if (_activeIp != _wifiIp) {
        try {
          _socket = await Socket.connect(_ethernetIp, _port, timeout: const Duration(seconds: 3));
          _activeIp = _ethernetIp;
          _isConnected = true;
          return true;
        } catch (e) {
          print('❌ Ethernet failed: $e. Trying WiFi...');
        }
      }

      try {
        _socket = await Socket.connect(_wifiIp, _port, timeout: const Duration(seconds: 3));
        _activeIp = _wifiIp;
        _isConnected = true;
        return true;
      } catch (e) {
        print('❌ WiFi failed: $e');
      }

      _isConnected = false;
      _activeIp = '';
      return false;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) await sub.cancel();

    final sock = _socket;
    _socket = null;
    if (sock != null) {
      try { await sock.close(); } catch (_) {}
      try { sock.destroy(); } catch (_) {}
    }
    _isConnected = false;
  }

  Future<String> _sendAndAwait(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    final ok = await connect();
    if (!ok) return 'ERROR: Not connected';

    final completer = Completer<String>();
    Timer? timer;
    final sock = _socket!;

    try {
      sock.write('$command\n');
      await sock.flush();

      final sub = sock.listen(
            (data) {
          final resp = String.fromCharCodes(data).trim();
          timer?.cancel();
          if (!completer.isCompleted) completer.complete(resp);
        },
        onError: (e) {
          timer?.cancel();
          if (!completer.isCompleted) completer.complete('ERROR: $e');
        },
        onDone: () {
          timer?.cancel();
          if (!completer.isCompleted) completer.complete('ERROR: Connection closed');
        },
        cancelOnError: true,
      );
      _subscription = sub;

      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete('ERROR: Timeout');
        sub.cancel();
      });

      return await completer.future;
    } catch (e) {
      timer?.cancel();
      _isConnected = false;
      return 'ERROR: $e';
    } finally {
      final sub = _subscription;
      _subscription = null;
      if (sub != null) await sub.cancel();

      final s = _socket;
      _socket = null;
      if (s != null) {
        try { await s.close(); } catch (_) {}
        try { s.destroy(); } catch (_) {}
      }
      _isConnected = false;
    }
  }

  // ----- GATE 1 COMMANDS -----
  Future<String> sendCommand(String command) => _sendAndAwait(command);
  Future<bool> openGate() async => !(await _sendAndAwait('GATE_OPEN')).startsWith('ERROR');
  Future<bool> manualGateUp() async => (await _sendAndAwait('MANUAL_UP')).contains('GATE_UP');
  Future<bool> manualGateDown() async => (await _sendAndAwait('MANUAL_DOWN')).contains('GATE_DOWN');
  Future<bool> registerGate1Tag(String id, String name) async => !(await _sendAndAwait('REGISTER:$id:$name')).startsWith('ERROR');
  Future<bool> cancelGate1Registration() async => (await _sendAndAwait('CANCEL_REGISTRATION')).contains('CANCELLED');

  // ----- GATE 2 COMMANDS (NEW) -----
  Future<bool> openGate2() async => !(await _sendAndAwait('GATE2_OPEN')).startsWith('ERROR');
  Future<bool> manualGate2Up() async => (await _sendAndAwait('GATE2_MANUAL_UP')).contains('GATE_UP');
  Future<bool> manualGate2Down() async => (await _sendAndAwait('GATE2_MANUAL_DOWN')).contains('GATE_DOWN');
  Future<bool> registerGate2Tag(String id, String name) async => !(await _sendAndAwait('REGISTER_G2:$id:$name')).startsWith('ERROR');
  Future<bool> cancelGate2Registration() async => (await _sendAndAwait('CANCEL_REGISTRATION_G2')).contains('CANCELLED');

  Future<bool> checkConnection() async => !(await _sendAndAwait('PING', timeout: const Duration(seconds: 2))).startsWith('ERROR');
  Future<bool> ensureConnection() async => connect();
}