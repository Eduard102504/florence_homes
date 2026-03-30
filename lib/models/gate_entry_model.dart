class GateEntryModel {
  String id;
  String residentId;
  String residentName;
  String entryType;
  DateTime timestamp;
  String? visitorName;
  String? qrCode;
  String status;

  GateEntryModel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.entryType,
    required this.timestamp,
    this.visitorName,
    this.qrCode,
    required this.status,
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
    );
  }
}