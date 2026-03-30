// lib/services/unified_scanner_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bluetooth_scanner_service.dart';
import 'usb_scanner_service.dart';
import 'network_scanner_service.dart';
import 'gate_control_service.dart';

enum ScannerSource { bluetooth, usb, network, nfc }

class RFIDScanEvent {
  final ScannerSource source;
  final String rfidData;
  final bool success;
  final String message;
  final Map<String, dynamic>? resident;
  final DateTime timestamp;

  RFIDScanEvent({
    required this.source,
    required this.rfidData,
    this.success = false,
    this.message = '',
    this.resident,
    required this.timestamp,
  });

  RFIDScanEvent copyWith({
    ScannerSource? source,
    String? rfidData,
    bool? success,
    String? message,
    Map<String, dynamic>? resident,
    DateTime? timestamp,
  }) {
    return RFIDScanEvent(
      source: source ?? this.source,
      rfidData: rfidData ?? this.rfidData,
      success: success ?? this.success,
      message: message ?? this.message,
      resident: resident ?? this.resident,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class UnifiedScannerService {
  static final UnifiedScannerService _instance = UnifiedScannerService._internal();
  factory UnifiedScannerService() => _instance;
  static UnifiedScannerService get instance => _instance;

  UnifiedScannerService._internal();

  final BluetoothScannerService _btService = BluetoothScannerService.instance;
  final USBScannerService _usbService = USBScannerService.instance;
  final NetworkScannerService _netService = NetworkScannerService.instance;
  final GateControlService _gateService = GateControlService();

  final StreamController<RFIDScanEvent> _scanEventController =
  StreamController<RFIDScanEvent>.broadcast();
  Stream<RFIDScanEvent> get scanEvents => _scanEventController.stream;

  Future<void> initialize() async {
    _setupScanListeners();
  }

  void _setupScanListeners() {
    _btService.rfidResults.listen((result) {
      _scanEventController.add(RFIDScanEvent(
        source: ScannerSource.bluetooth,
        rfidData: result.rfidData,
        success: result.success,
        message: result.message,
        resident: result.resident,
        timestamp: DateTime.now(),
      ));
    });

    _usbService.rfidDataStream.listen((rfidData) {
      _scanEventController.add(RFIDScanEvent(
        source: ScannerSource.usb,
        rfidData: rfidData,
        timestamp: DateTime.now(),
      ));
    });

    _netService.rfidDataStream.listen((rfidData) {
      _scanEventController.add(RFIDScanEvent(
        source: ScannerSource.network,
        rfidData: rfidData,
        timestamp: DateTime.now(),
      ));
    });
  }

  void dispose() {
    _scanEventController.close();
  }
}