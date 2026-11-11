// lib/models/gate_entry_model.dart
class GateEntryModel {
  String id;
  String residentId;
  String residentName;
  String entryType;
  DateTime timestamp;
  String? visitorName;
  String? qrCode;
  String status;
  String? gate; // ✅ NEW — 'Gate 1' or 'Gate 2'

  GateEntryModel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.entryType,
    required this.timestamp,
    this.visitorName,
    this.qrCode,
    required this.status,
    this.gate,
  });

  Map<String, dynamic> toMap() {
    return {
      'residentId': residentId,
      'residentName': residentName,
      'entryType': entryType,
      'timestamp': timestamp,
      'visitorName': visitorName,
      'qrCode': qrCode,
      'status': status,
      'gate': gate, // ✅ NEW
    };
  }

  factory GateEntryModel.fromMap(String id, Map<String, dynamic> map) {
    return GateEntryModel(
      id: id,
      residentId: map['residentId'] ?? '',
      residentName: map['residentName'] ?? '',
      entryType: map['entryType'] ?? '',
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      visitorName: map['visitorName'],
      qrCode: map['qrCode'],
      status: map['status'] ?? 'entry',
      gate: map['gate'], // ✅ NEW
    );
  }
}