class ResidentModel {
  String? id;
  String fullName;
  String email;
  String houseNumber;
  String? phoneNumber;
  String? rfidTag;
  bool isActive;
  DateTime createdAt;
  DateTime? lastAccess;

  ResidentModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.houseNumber,
    this.phoneNumber,
    this.rfidTag,
    this.isActive = true,
    required this.createdAt,
    this.lastAccess,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'houseNumber': houseNumber,
      'phoneNumber': phoneNumber,
      'rfidTag': rfidTag,
      'isActive': isActive,
      'createdAt': createdAt,
      'lastAccess': lastAccess,
    };
  }

  factory ResidentModel.fromMap(String id, Map<String, dynamic> map) {
    return ResidentModel(
      id: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      houseNumber: map['houseNumber'] ?? '',
      phoneNumber: map['phoneNumber'],
      rfidTag: map['rfidTag'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastAccess: (map['lastAccess'] as dynamic)?.toDate(),
    );
  }
}