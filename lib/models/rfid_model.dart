class RFIDModel {
  String? id;
  String rfidData;
  String residentId;
  String? residentName;
  DateTime assignedAt;
  bool isActive;

  RFIDModel({
    this.id,
    required this.rfidData,
    required this.residentId,
    this.residentName,
    required this.assignedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'rfidData': rfidData,
      'residentId': residentId,
      'residentName': residentName,
      'assignedAt': assignedAt,
      'isActive': isActive,
    };
  }

  factory RFIDModel.fromMap(String id, Map<String, dynamic> map) {
    return RFIDModel(
      id: id,
      rfidData: map['rfidData'] ?? '',
      residentId: map['residentId'] ?? '',
      residentName: map['residentName'],
      assignedAt: (map['assignedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }
}