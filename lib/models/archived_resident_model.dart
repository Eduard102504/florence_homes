import 'package:cloud_firestore/cloud_firestore.dart';

class ArchivedResidentModel {
  String? id;                  // original user doc id
  String? archiveId;           // archive doc id
  String? residentId;          // FHM-###
  String fullName;
  String email;
  String? houseNumber;
  String? phoneNumber;
  String? rfidTag;
  String userType;
  bool wasApproved;
  DateTime createdAt;
  DateTime archivedAt;
  String? archivedBy;
  String? archivedByName;
  String? deleteReason;

  ArchivedResidentModel({
    this.id,
    this.archiveId,
    this.residentId,
    required this.fullName,
    required this.email,
    this.houseNumber,
    this.phoneNumber,
    this.rfidTag,
    this.userType = 'resident',
    this.wasApproved = false,
    required this.createdAt,
    required this.archivedAt,
    this.archivedBy,
    this.archivedByName,
    this.deleteReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalId': id,
      'residentId': residentId,
      'fullName': fullName,
      'email': email,
      'houseNumber': houseNumber,
      'phoneNumber': phoneNumber,
      'rfidTag': rfidTag,
      'userType': userType,
      'wasApproved': wasApproved,
      'createdAt': createdAt,
      'archivedAt': archivedAt,
      'archivedBy': archivedBy,
      'archivedByName': archivedByName,
      'deleteReason': deleteReason,
    };
  }

  factory ArchivedResidentModel.fromMap(
      String archiveId, Map<String, dynamic> map) {
    return ArchivedResidentModel(
      archiveId: archiveId,
      id: map['originalId'],
      residentId: map['residentId'],
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      houseNumber: map['houseNumber'],
      phoneNumber: map['phoneNumber'],
      rfidTag: map['rfidTag'],
      userType: map['userType'] ?? 'resident',
      wasApproved: map['wasApproved'] ?? false,
      createdAt:
      (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      archivedAt:
      (map['archivedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      archivedBy: map['archivedBy'],
      archivedByName: map['archivedByName'],
      deleteReason: map['deleteReason'],
    );
  }
}