class VisitorQRModel {
  String? id;
  String residentId;
  String residentName;
  String visitorName;
  DateTime generatedAt;
  DateTime expiresAt;
  bool isUsed;
  DateTime? usedAt;
  String? qrCodeData;

  VisitorQRModel({
    this.id,
    required this.residentId,
    required this.residentName,
    required this.visitorName,
    required this.generatedAt,
    required this.expiresAt,
    this.isUsed = false,
    this.usedAt,
    this.qrCodeData,
  });

  Map<String, dynamic> toMap() {
    return {
      'residentId': residentId,
      'residentName': residentName,
      'visitorName': visitorName,
      'generatedAt': generatedAt,
      'expiresAt': expiresAt,
      'isUsed': isUsed,
      'usedAt': usedAt,
      'qrCodeData': qrCodeData,
    };
  }

  factory VisitorQRModel.fromMap(String id, Map<String, dynamic> map) {
    return VisitorQRModel(
      id: id,
      residentId: map['residentId'] ?? '',
      residentName: map['residentName'] ?? '',
      visitorName: map['visitorName'] ?? '',
      generatedAt: (map['generatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isUsed: map['isUsed'] ?? false,
      usedAt: (map['usedAt'] as dynamic)?.toDate(),
      qrCodeData: map['qrCodeData'],
    );
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  String get status {
    if (isUsed) return 'Used';
    if (isExpired) return 'Expired';
    return 'Active';
  }
}