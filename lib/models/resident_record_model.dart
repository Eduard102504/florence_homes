import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentRecordModel {
  String? recordId;         // record doc id
  String? originalId;       // original user uid
  String? residentId;       // FHM-###
  String fullName;
  String email;
  String? houseNumber;
  String? phoneNumber;
  String? rfidTag;
  String userType;
  bool wasApproved;
  DateTime createdAt;       // original registration date
  DateTime archivedAt;      // when first archived
  DateTime recordedAt;      // when moved to Records
  String? archivedBy;       // admin uid who archived
  String? archivedByName;
  String? deleteReason;
  String? movedBy;          // admin uid who moved to records (or 'system')
  String? movedByName;

  ResidentRecordModel({
    this.recordId,
    this.originalId,
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
    required this.recordedAt,
    this.archivedBy,
    this.archivedByName,
    this.deleteReason,
    this.movedBy,
    this.movedByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalId': originalId,
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
      'recordedAt': recordedAt,
      'archivedBy': archivedBy,
      'archivedByName': archivedByName,
      'deleteReason': deleteReason,
      'movedBy': movedBy,
      'movedByName': movedByName,
    };
  }

  factory ResidentRecordModel.fromMap(
      String recordId, Map<String, dynamic> map) {
    return ResidentRecordModel(
      recordId: recordId,
      originalId: map['originalId'],
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
      recordedAt:
      (map['recordedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      archivedBy: map['archivedBy'],
      archivedByName: map['archivedByName'],
      deleteReason: map['deleteReason'],
      movedBy: map['movedBy'],
      movedByName: map['movedByName'],
    );
  }
}