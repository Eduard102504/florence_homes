// lib/services/tcp_service.dart
import 'dart:io';
import 'dart:async';

class TCPService {
  static final TCPService _instance = TCPService._internal();
  factory TCPService() => _instance;
  TCPService._internal();

  Socket? _socket;
  bool _isConnected = false;

  // ✅ FALLBACK SETTINGS
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
      // 1. Clean up old socket
      final oldSub = _subscription;
      _subscription = null;
      if (oldSub != null) await oldSub.cancel();

      final oldSocket = _socket;
      _socket = null;
      if (oldSocket != null) {
        try { await oldSocket.close(); } catch (_) {}
        try { oldSocket.destroy(); } catch (_) {}
      }

      // 2. Try Ethernet first (if we haven't already locked onto WiFi)
      if (_activeIp != _wifiIp) {
        try {
          print('🔌 Trying Ethernet: $_ethernetIp...');
          _socket = await Socket.connect(
            _ethernetIp, _port, timeout: const Duration(seconds: 3),
          );
          _activeIp = _ethernetIp;
          _isConnected = true;
          print('✅ Connected to Ethernet ($_ethernetIp)');
          return true;
        } catch (e) {
          print('❌ Ethernet failed: $e. Trying WiFi...');
        }
      }

      // 3. Try WiFi fallback
      try {
        print('🔌 Trying WiFi: $_wifiIp...');
        _socket = await Socket.connect(
          _wifiIp, _port, timeout: const Duration(seconds: 3),
        );
        _activeIp = _wifiIp;
        _isConnected = true;
        print('✅ Connected to WiFi ($_wifiIp)');
        return true;
      } catch (e) {
        print('❌ WiFi failed: $e');
      }

      // 4. Both failed
      _isConnected = false;
      _activeIp = '';
      print('❌ Could not connect to Pi on Ethernet or WiFi');
      return false;
    } catch (e) {
      print('Connection failed: $e');
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
    print('Disconnected from Raspberry Pi');
  }

  Future<String> _sendAndAwait(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    final ok = await connect();
    if (!ok) return 'ERROR: Not connected to Raspberry Pi';

    final completer = Completer<String>();
    Timer? timer;
    final sock = _socket!;

    try {
      sock.write('$command\n');
      await sock.flush();
      print('Sent command: $command');

      final sub = sock.listen(
            (data) {
          final resp = String.fromCharCodes(data).trim();
          print('Received response: $resp');
          timer?.cancel();
          if (!completer.isCompleted) completer.complete(resp);
        },
        onError: (e) {
          print('Socket error: $e');
          timer?.cancel();
          if (!completer.isCompleted) completer.complete('ERROR: $e');
        },
        onDone: () {
          print('Socket done');
          timer?.cancel();
          if (!completer.isCompleted) completer.complete('ERROR: Connection closed');
        },
        cancelOnError: true,
      );
      _subscription = sub;

      timer = Timer(timeout, () {
        print('Timeout waiting for response');
        if (!completer.isCompleted) completer.complete('ERROR: Timeout');
        sub.cancel();
      });

      return await completer.future;
    } catch (e) {
      print('Send command error: $e');
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

  // ----- High-level gate commands -----
  Future<String> sendCommand(String command) => _sendAndAwait(command);

  Future<bool> openGate() async {
    final r = await _sendAndAwait('GATE_OPEN');
    return !r.startsWith('ERROR');
  }

  Future<bool> manualGateUp() async {
    final r = await _sendAndAwait('MANUAL_UP');
    return r.contains('GATE_UP');
  }

  Future<bool> manualGateDown() async {
    final r = await _sendAndAwait('MANUAL_DOWN');
    return r.contains('GATE_DOWN');
  }

  Future<bool> checkConnection() async {
    final r = await _sendAndAwait('PING', timeout: const Duration(seconds: 2));
    return !r.startsWith('ERROR');
  }

  Future<bool> ensureConnection() async => connect();
}