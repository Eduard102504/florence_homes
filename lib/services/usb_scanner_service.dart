import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';

class USBScannerService {
  static USBScannerService? _instance;
  static USBScannerService get instance {
    _instance ??= USBScannerService._internal();
    return _instance!;
  }

  USBScannerService._internal();

  UsbPort? _port;
  StreamSubscription? _subscription;
  final List<int> _buffer = [];
  List<UsbDevice> _devices = [];

  Future<List<UsbDevice>> scanForDevices() async {
    try {
      _devices = await UsbSerial.listDevices();
      return _devices;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connectToScanner(UsbDevice device) async {
    try {
      _port = await device.create();

      if (_port == null) {
        return false;
      }

      bool openResult = await _port!.open();
      if (!openResult) {
        return false;
      }

      await _port!.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _subscription = _port!.inputStream?.listen(_handleData);

      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleData(Uint8List data) {
    for (int byte in data) {
      if (byte == 13 || byte == 10) {
        if (_buffer.isNotEmpty) {
          String rfidData = String.fromCharCodes(_buffer);
          _rfidStreamController.add(rfidData.trim());
          _buffer.clear();
        }
      } else {
        _buffer.add(byte);
      }
    }
  }

  final StreamController<String> _rfidStreamController =
  StreamController<String>.broadcast();
  Stream<String> get rfidDataStream => _rfidStreamController.stream;

  Future<void> connectToPreferred() async {
    var devices = await scanForDevices();
    if (devices.isNotEmpty) {
      await connectToScanner(devices.first);
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _port?.close();
    _port = null;
  }
}