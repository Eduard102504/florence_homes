import 'package:flutter/material.dart';
import '../services/gate_service.dart';
import '../models/gate_entry_model.dart';

class GateProvider extends ChangeNotifier {
  final GateService _gateService = GateService();
  List<GateEntryModel> _recentEntries = [];
  bool _isScanning = false;
  String? _lastScanResult;

  List<GateEntryModel> get recentEntries => _recentEntries;
  bool get isScanning => _isScanning;
  String? get lastScanResult => _lastScanResult;

  Future<void> recordEntry({
    required String residentId,
    required String residentName,
    required String entryType,
    String? visitorName,
    String? qrCode,
    required String status,
  }) async {
    bool success = await _gateService.recordGateEntry(
      residentId: residentId,
      residentName: residentName,
      entryType: entryType,
      visitorName: visitorName,
      qrCode: qrCode,
      status: status,
    );

    if (success) {
      await loadRecentEntries();
    }

    notifyListeners();
  }

  Future<void> loadRecentEntries() async {
    // Fix: Convert the list to GateEntryModel if needed
    var entries = await _gateService.getGateEntries();
    _recentEntries = entries.cast<GateEntryModel>();
    notifyListeners();
  }

  Future<Map<String, dynamic>> scanRFID(String rfidData) async {
    _isScanning = true;
    _lastScanResult = 'Scanning...';
    notifyListeners();

    var result = await _gateService.scanRFID(rfidData);

    _isScanning = false;
    _lastScanResult = result['message'];
    notifyListeners();

    if (result['success']) {
      await loadRecentEntries();
    }

    return result;
  }

  Future<Map<String, dynamic>> scanQR(String qrData) async {
    _isScanning = true;
    _lastScanResult = 'Scanning...';
    notifyListeners();

    var result = await _gateService.scanQR(qrData);

    _isScanning = false;
    _lastScanResult = result['message'];
    notifyListeners();

    if (result['success']) {
      await loadRecentEntries();
    }

    return result;
  }

  void clearLastScan() {
    _lastScanResult = null;
    notifyListeners();
  }
}