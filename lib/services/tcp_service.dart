import 'dart:io';
import 'dart:async';

class TCPService {
  static final TCPService _instance = TCPService._internal();
  factory TCPService() => _instance;
  TCPService._internal();

  Socket? _socket;
  bool _isConnected = false;
  String _raspberryPiIp = '192.168.1.9'; // Change to your Raspberry Pi's IP
  int _port = 8080;
  StreamSubscription<List<int>>? _subscription;

  bool get isConnected => _isConnected;

  void setPiIp(String ip) => _raspberryPiIp = ip;
  void setPort(int port) => _port = port;

  // ⭐ Recreate socket every call → listen() always works
  Future<bool> connect() async {
    try {
      // Tear down anything old first
      final oldSub = _subscription;
      _subscription = null;
      if (oldSub != null) {
        await oldSub.cancel();
      }

      final oldSocket = _socket;
      _socket = null;
      if (oldSocket != null) {
        try {
          await oldSocket.close();
        } catch (_) {}
        try {
          oldSocket.destroy();
        } catch (_) {}
      }

      _socket = await Socket.connect(
        _raspberryPiIp,
        _port,
        timeout: const Duration(seconds: 5),
      );
      _isConnected = true;
      print('Connected to Raspberry Pi at $_raspberryPiIp:$_port');
      return true;
    } catch (e) {
      print('Connection failed to $_raspberryPiIp:$_port - Error: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      await sub.cancel();
    }

    final sock = _socket;
    _socket = null;
    if (sock != null) {
      try {
        await sock.close();
      } catch (_) {}
      try {
        sock.destroy();
      } catch (_) {}
    }

    _isConnected = false;
    print('Disconnected from Raspberry Pi');
  }

  // ⭐ LIVE-RELIABLE COMMAND HELPER
  Future<String> _sendAndAwait(
      String command, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
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
          if (!completer.isCompleted) {
            completer.complete('ERROR: Connection closed');
          }
        },
        cancelOnError: true,
      );
      _subscription = sub;

      timer = Timer(timeout, () {
        print('Timeout waiting for response');
        if (!completer.isCompleted) completer.complete('ERROR: Timeout');
        sub.cancel();
      });

      final result = await completer.future;
      return result;
    } catch (e) {
      print('Send command error: $e');
      timer?.cancel();
      _isConnected = false;
      return 'ERROR: $e';
    } finally {
      // Clean up so the NEXT call starts fresh
      final sub = _subscription;
      _subscription = null;
      if (sub != null) {
        await sub.cancel();
      }

      final s = _socket;
      _socket = null;
      if (s != null) {
        try {
          await s.close();
        } catch (_) {}
        try {
          s.destroy();
        } catch (_) {}
      }

      _isConnected = false;
    }
  }

  // Backward-compatible API used by other screens
  Future<String> sendCommand(String command) => _sendAndAwait(command);

  // ----- High-level gate commands -----

  Future<bool> openGate() async {
    final r = await _sendAndAwait('GATE_OPEN');
    if (r.startsWith('ERROR')) return false;
    return true;
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
    final r = await _sendAndAwait('PING',
        timeout: const Duration(seconds: 2));
    return !r.startsWith('ERROR');
  }

  Future<bool> ensureConnection() async => connect();
}