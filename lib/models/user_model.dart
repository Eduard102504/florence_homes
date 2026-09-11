import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? id;
  String email;
  String fullName;
  String userType;
  bool isApproved;
  DateTime createdAt;
  String? rfidTag;
  String? houseNumber;
  String? phoneNumber;

  UserModel({
    this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.isApproved = false,
    required this.createdAt,
    this.rfidTag,
    this.houseNumber,
    this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'isApproved': isApproved,
      'createdAt': createdAt,
      'rfidTag': rfidTag,
      'houseNumber': houseNumber,
      'phoneNumber': phoneNumber,
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      userType: map['userType'] ?? 'resident',
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      rfidTag: map['rfidTag'],
      houseNumber: map['houseNumber'],
      phoneNumber: map['phoneNumber'],
    );
  }
}