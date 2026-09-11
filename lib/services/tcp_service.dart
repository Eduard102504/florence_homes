import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

class TCPService {
  static final TCPService _instance = TCPService._internal();
  factory TCPService() => _instance;
  TCPService._internal();

  Socket? _socket;
  bool _isConnected = false;
  String _raspberryPiIp = '192.168.1.9'; // Change to your Raspberry Pi's IP address
  int _port = 8080;
  StreamSubscription<List<int>>? _subscription;

  bool get isConnected => _isConnected;

  void setPiIp(String ip) {
    _raspberryPiIp = ip;
  }

  void setPort(int port) {
    _port = port;
  }

  Future<bool> connect() async {
    try {
      _socket = await Socket.connect(_raspberryPiIp, _port, timeout: const Duration(seconds: 5));
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
    await _subscription?.cancel();
    await _socket?.close();
    _isConnected = false;
    print('Disconnected from Raspberry Pi');
  }

  // Send command and wait for response
  Future<String> sendCommand(String command) async {
    if (!_isConnected) {
      bool connected = await connect();
      if (!connected) {
        return 'ERROR: Not connected to Raspberry Pi';
      }
    }

    Completer<String> completer = Completer();
    Timer? timeoutTimer;

    try {
      // Send command
      _socket!.write('$command\n');
      await _socket!.flush();
      print('Sent command: $command');

      // Listen for response
      _subscription = _socket!.listen(
            (data) {
          String response = String.fromCharCodes(data).trim();
          print('Received response: $response');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        },
        onError: (error) {
          print('Socket error: $error');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete('ERROR: $error');
          }
        },
        onDone: () {
          print('Socket done');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete('ERROR: Connection closed');
          }
        },
        cancelOnError: true,
      );

      // Set timeout
      timeoutTimer = Timer(const Duration(seconds: 5), () {
        print('Timeout waiting for response');
        _subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete('ERROR: Timeout');
        }
      });

      return await completer.future;
    } catch (e) {
      print('Send command error: $e');
      timeoutTimer?.cancel();
      _isConnected = false;
      return 'ERROR: $e';
    }
  }

  // Dedicated method to open gate (doesn't close connection)
  Future<bool> openGate() async {
    if (!_isConnected) {
      bool connected = await connect();
      if (!connected) {
        print('Cannot open gate: Not connected to Raspberry Pi');
        return false;
      }
    }

    try {
      _socket!.write('GATE_OPEN\n');
      await _socket!.flush();
      print('Gate open command sent to Raspberry Pi');
      return true;
    } catch (e) {
      print('Error sending gate open command: $e');
      _isConnected = false;
      return false;
    }
  }

  // Check if connection is alive
  Future<bool> checkConnection() async {
    if (!_isConnected) {
      return false;
    }

    try {
      // Send a heartbeat command
      _socket!.write('PING\n');
      await _socket!.flush();
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // Reconnect if needed
  Future<bool> ensureConnection() async {
    if (!_isConnected) {
      return await connect();
    }
    return true;
  }
}