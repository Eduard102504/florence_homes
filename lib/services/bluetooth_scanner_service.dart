import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BluetoothScannerService {
  static BluetoothScannerService? _instance;
  static BluetoothScannerService get instance {
    _instance ??= BluetoothScannerService._internal();
    return _instance!;
  }

  BluetoothScannerService._internal();

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _readSubscription;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> supportedScanners = [
    'RFID Scanner',
    'Zebra RS5100',
    'Chainway C61',
    'Honeywell 8650',
    'Socket Mobile',
    'Generic Barcode Scanner'
  ];

  Future<bool> checkPermissions() async {
    PermissionStatus bluetoothScan = await Permission.bluetoothScan.status;
    PermissionStatus bluetoothConnect = await Permission.bluetoothConnect.status;
    PermissionStatus location = await Permission.location.status;

    if (bluetoothScan.isDenied) {
      bluetoothScan = await Permission.bluetoothScan.request();
    }
    if (bluetoothConnect.isDenied) {
      bluetoothConnect = await Permission.bluetoothConnect.request();
    }
    if (location.isDenied) {
      location = await Permission.location.request();
    }

    return bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted;
  }

  Stream<List<ScanResult>> startScanning() async* {
    if (await checkPermissions()) {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
      yield* FlutterBluePlus.scanResults;
    }
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connectToScanner(BluetoothDevice device) async {
    try {
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _listenForRFIDReads(device);
        }
      });

      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  void _listenForRFIDReads(BluetoothDevice device) {
    device.discoverServices().then((services) {
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().contains('fff1') ||
              characteristic.properties.read) {
            _readSubscription = characteristic.value.listen((value) {
              String rfidData = String.fromCharCodes(value);
              _processScannedRFID(rfidData);
            });

            if (characteristic.properties.notify) {
              characteristic.setNotifyValue(true);
            }
          }
        }
      }
    });
  }

  Future<void> _processScannedRFID(String rfidData) async {
    try {
      DocumentSnapshot rfidDoc = await _firestore
          .collection('rfid_tags')
          .doc(rfidData)
          .get();

      if (!rfidDoc.exists) {
        _notifyRFIDResult(false, 'Invalid or unregistered RFID tag');
        return;
      }

      String residentId = rfidDoc.get('residentId');
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(residentId)
          .get();

      if (!residentDoc.exists) {
        _notifyRFIDResult(false, 'Resident not found');
        return;
      }

      _notifyRFIDResult(
          true,
          'Access Granted for ${residentDoc.get('fullName')}',
          resident: residentDoc.data() as Map<String, dynamic>?
      );

    } catch (e) {
      _notifyRFIDResult(false, 'Error processing RFID: $e');
    }
  }

  final StreamController<RFIDResult> _rfidResultController =
  StreamController<RFIDResult>.broadcast();
  Stream<RFIDResult> get rfidResults => _rfidResultController.stream;

  void _notifyRFIDResult(bool success, String message, {Map<String, dynamic>? resident}) {
    _rfidResultController.add(RFIDResult(
      success: success,
      message: message,
      resident: resident,
      timestamp: DateTime.now(),
      rfidData: '',
    ));
  }

  Future<void> scanAndConnect() async {
    await startScanning();
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    await _readSubscription?.cancel();
    await _connectionSubscription?.cancel();
  }

  void dispose() {
    _rfidResultController.close();
    disconnect();
  }
}

class RFIDResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? resident;
  final DateTime timestamp;
  final String rfidData;

  RFIDResult({
    required this.success,
    required this.message,
    this.resident,
    required this.timestamp,
    required this.rfidData,
  });
}