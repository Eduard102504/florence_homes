// lib/services/gate_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gate_entry_model.dart';
import 'dart:convert';
import 'dart:typed_data';

class GateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> recordGateEntry({
    required String residentId,
    required String residentName,
    required String entryType,
    String? visitorName,
    String? qrCode,
    required String status,
  }) async {
    try {
      await _firestore.collection('gate_entries').add({
        'residentId': residentId,
        'residentName': residentName,
        'entryType': entryType,
        'timestamp': DateTime.now(),
        'visitorName': visitorName,
        'qrCode': qrCode,
        'status': status,
      });

      await _firestore.collection('users').doc(residentId).update({
        'lastAccess': DateTime.now(),
        'lastAccessType': entryType,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> scanRFID(String rfidData) async {
    try {
      DocumentSnapshot rfidDoc = await _firestore
          .collection('rfid_tags')
          .doc(rfidData)
          .get();

      if (!rfidDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid or unregistered RFID tag',
        };
      }

      String residentId = rfidDoc.get('residentId');
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(residentId)
          .get();

      return {
        'success': true,
        'residentId': residentId,
        'residentName': residentDoc.get('fullName'),
        'message': 'Access granted for ${residentDoc.get('fullName')}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing RFID: $e',
      };
    }
  }

  Future<Map<String, dynamic>> scanQR(String qrData) async {
    try {
      // Try to decode as base64 (visitor QR)
      String decodedString;
      try {
        decodedString = utf8.decode(base64.decode(qrData));
      } catch (e) {
        // Not base64, treat as resident ID
        return await _validateResidentQR(qrData);
      }

      // Try to parse as JSON
      Map<String, dynamic> qrInfo;
      try {
        qrInfo = json.decode(decodedString);
      } catch (e) {
        return await _validateResidentQR(qrData);
      }

      // Check if it's a visitor QR (has 'id' field)
      if (qrInfo.containsKey('id')) {
        return await _validateVisitorQR(qrInfo);
      } else {
        return await _validateResidentQR(qrData);
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing QR: $e',
      };
    }
  }

// Add this method AFTER scanQR
  Future<Map<String, dynamic>> _validateVisitorQR(Map<String, dynamic> qrInfo) async {
    try {
      String qrId = qrInfo['id'];
      DocumentSnapshot qrDoc = await _firestore
          .collection('visitor_qrs')
          .doc(qrId)
          .get();

      if (!qrDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid QR code',
        };
      }

      Map<String, dynamic> qrData = qrDoc.data() as Map<String, dynamic>;

      if (qrData['isUsed'] == true) {
        return {
          'success': false,
          'message': 'QR code has already been used',
        };
      }

      DateTime expiresAt = DateTime.parse(qrData['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'QR code has expired',
        };
      }

      // Mark as used
      await _firestore.collection('visitor_qrs').doc(qrId).update({
        'isUsed': true,
        'usedAt': DateTime.now(),
      });

      // Record gate entry
      await recordGateEntry(
        residentId: qrData['residentId'],
        residentName: qrData['residentName'],
        entryType: 'QR_VISITOR',
        visitorName: qrData['visitorName'],
        qrCode: qrId,
        status: 'success',
      );

      return {
        'success': true,
        'residentId': qrData['residentId'],
        'residentName': qrData['residentName'],
        'visitorName': qrData['visitorName'],
        'message': 'Welcome ${qrData['visitorName']}! Visitor of ${qrData['residentName']}',
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error validating visitor QR: $e',
      };
    }
  }

// Add this method AFTER _validateVisitorQR
  Future<Map<String, dynamic>> _validateResidentQR(String qrData) async {
    try {
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(qrData)
          .get();

      if (!residentDoc.exists) {
        return {
          'success': false,
          'message': 'Resident not found',
        };
      }

      Map<String, dynamic> residentData = residentDoc.data() as Map<String, dynamic>;

      if (residentData['isActive'] != true) {
        return {
          'success': false,
          'message': 'Resident account is not active',
        };
      }

      await recordGateEntry(
        residentId: qrData,
        residentName: residentData['fullName'],
        entryType: 'QR_RESIDENT',
        status: 'success',
      );

      return {
        'success': true,
        'residentId': qrData,
        'residentName': residentData['fullName'],
        'message': 'Welcome back ${residentData['fullName']}!',
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error validating resident QR: $e',
      };
    }
  }
  Future<List<GateEntryModel>> getGateEntries() async {
    QuerySnapshot snapshot = await _firestore
        .collection('gate_entries')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return GateEntryModel(
        id: doc.id,
        residentId: data['residentId'],
        residentName: data['residentName'],
        entryType: data['entryType'],
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        visitorName: data['visitorName'],
        qrCode: data['qrCode'],
        status: data['status'],
      );
    }).toList();
  }
  Future<Map<String, dynamic>> getResidentDetails(String residentId) async {
    try {
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(residentId)
          .get();

      if (!residentDoc.exists) {
        return {};
      }

      Map<String, dynamic> data = residentDoc.data() as Map<String, dynamic>;
      return {
        'fullName': data['fullName'] ?? '',
        'houseNumber': data['houseNumber'] ?? '',
        'email': data['email'] ?? '',
        'phoneNumber': data['phoneNumber'],
        'rfidTag': data['rfidTag'],
        'isActive': data['isActive'] ?? true,
        'createdAt': (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      };
    } catch (e) {
      print('Error getting resident details: $e');
      return {};
    }
  }
}
