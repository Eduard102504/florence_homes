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
      final entryData = {
        'residentId': residentId,
        'residentName': residentName,
        'entryType': entryType,
        'timestamp': FieldValue.serverTimestamp(),
        'visitorName': visitorName ?? '',
        'qrCode': qrCode ?? '',
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print("📝 Recording entry: $entryData");

      await _firestore.collection('gate_entries').add(entryData);

      // Update resident's last access
      await _firestore.collection('users').doc(residentId).update({
        'lastAccess': FieldValue.serverTimestamp(),
        'lastAccessType': entryType,
      });

      return true;
    } catch (e) {
      print("❌ Error recording entry: $e");
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
    print("🔍 RAW QR DATA: $qrData");

    try {
      // Clean the QR data - remove whitespace, newlines, and fix formatting
      String cleanedData = qrData.trim().replaceAll('\n', '').replaceAll('\r', '');
      print("📱 CLEANED DATA: $cleanedData");

      // Try to extract resident ID directly from the QR data
      // Look for common patterns
      String? residentId;
      String? residentName;
      String? visitorName;

      // Pattern 1: Look for "residentId" in the string
      RegExp residentIdRegex = RegExp(r'residentId["\s:=]+([a-zA-Z0-9]+)');
      RegExp residentNameRegex = RegExp(r'residentName["\s:=]+([a-zA-Z\s]+)');
      RegExp visitorNameRegex = RegExp(r'visitorName["\s:=]+([a-zA-Z\s]+)');

      residentId = residentIdRegex.firstMatch(cleanedData)?.group(1);
      residentName = residentNameRegex.firstMatch(cleanedData)?.group(1);
      visitorName = visitorNameRegex.firstMatch(cleanedData)?.group(1);

      print("🔍 EXTRACTED - residentId: $residentId, residentName: $residentName, visitorName: $visitorName");

      // If we found a residentId, validate it
      if (residentId != null && residentId.isNotEmpty) {
        // Check if resident exists
        DocumentSnapshot residentDoc = await _firestore
            .collection('users')
            .doc(residentId)
            .get();

        if (!residentDoc.exists) {
          return {
            'success': false,
            'message': 'Resident not found',
          };
        }

        Map<String, dynamic> residentData = residentDoc.data() as Map<String, dynamic>;
        String actualResidentName = residentData['fullName'] ?? residentName ?? 'Unknown';

        // Record gate entry
        await recordGateEntry(
          residentId: residentId,
          residentName: actualResidentName,
          entryType: 'QR_VISITOR',
          visitorName: visitorName ?? 'Guest',
          qrCode: qrData.substring(0, qrData.length > 50 ? 50 : qrData.length),
          status: 'success',
        );

        return {
          'success': true,
          'residentId': residentId,
          'residentName': actualResidentName,
          'visitorName': visitorName ?? 'Guest',
          'message': 'Welcome ${visitorName ?? "Guest"}! Visitor of $actualResidentName',
        };
      }

      // If no residentId found, try to decode as base64
      try {
        String decodedString = utf8.decode(base64.decode(cleanedData));
        print("📦 BASE64 DECODED: $decodedString");

        Map<String, dynamic> qrInfo = json.decode(decodedString);
        print("📦 PARSED JSON: $qrInfo");

        String qrResidentId = qrInfo['residentId'] ?? qrInfo['id'];
        String qrResidentName = qrInfo['residentName'] ?? '';
        String qrVisitorName = qrInfo['visitorName'] ?? 'Guest';

        if (qrResidentId != null && qrResidentId.isNotEmpty) {
          DocumentSnapshot residentDoc = await _firestore
              .collection('users')
              .doc(qrResidentId)
              .get();

          if (residentDoc.exists) {
            Map<String, dynamic> residentData = residentDoc.data() as Map<String, dynamic>;

            await recordGateEntry(
              residentId: qrResidentId,
              residentName: residentData['fullName'],
              entryType: 'QR_VISITOR',
              visitorName: qrVisitorName,
              qrCode: qrInfo['id'] ?? '',
              status: 'success',
            );

            return {
              'success': true,
              'residentId': qrResidentId,
              'residentName': residentData['fullName'],
              'visitorName': qrVisitorName,
              'message': 'Welcome $qrVisitorName! Visitor of ${residentData['fullName']}',
            };
          }
        }
      } catch (e) {
        print("Base64 decode failed: $e");
      }

      // Last resort: Try to use the QR data as resident ID directly
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(cleanedData)
          .get();

      if (residentDoc.exists) {
        Map<String, dynamic> residentData = residentDoc.data() as Map<String, dynamic>;

        await recordGateEntry(
          residentId: cleanedData,
          residentName: residentData['fullName'],
          entryType: 'QR_RESIDENT',
          status: 'success',
        );

        return {
          'success': true,
          'residentId': cleanedData,
          'residentName': residentData['fullName'],
          'message': 'Welcome back ${residentData['fullName']}!',
        };
      }

      return {
        'success': false,
        'message': 'Invalid QR code. Please use a valid visitor QR code.',
      };

    } catch (e) {
      print("❌ Error processing QR: $e");
      return {
        'success': false,
        'message': 'Error processing QR: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _validateVisitorQR(Map<String, dynamic> qrInfo) async {
    try {
      // Get the QR ID (could be 'id' or 'visitorId')
      String qrId = qrInfo['id'] ?? qrInfo['visitorId'];
      String residentId = qrInfo['residentId'];
      String visitorName = qrInfo['visitorName'] ?? qrInfo['visitorName'];
      String residentName = qrInfo['residentName'] ?? '';

      print("🔍 Validating visitor QR: ID=$qrId, ResidentID=$residentId");

      // Check if QR exists in visitor_qrs collection
      DocumentSnapshot qrDoc = await _firestore
          .collection('visitor_qrs')
          .doc(qrId)
          .get();

      if (!qrDoc.exists) {
        // If not found in visitor_qrs, try to get resident name from users collection
        DocumentSnapshot residentDoc = await _firestore
            .collection('users')
            .doc(residentId)
            .get();

        if (!residentDoc.exists) {
          return {
            'success': false,
            'message': 'Resident not found',
          };
        }

        residentName = residentDoc.get('fullName') ?? residentName;

        // Record entry even if QR not in visitor_qrs (direct scan)
        await recordGateEntry(
          residentId: residentId,
          residentName: residentName,
          entryType: 'QR_VISITOR',
          visitorName: visitorName,
          qrCode: qrId,
          status: 'success',
        );

        return {
          'success': true,
          'residentId': residentId,
          'residentName': residentName,
          'visitorName': visitorName,
          'message': 'Welcome $visitorName! Visitor of $residentName',
        };
      }

      // QR exists in database
      Map<String, dynamic> qrData = qrDoc.data() as Map<String, dynamic>;

      // Check if already used
      if (qrData['isUsed'] == true) {
        return {
          'success': false,
          'message': 'QR code has already been used',
        };
      }

      // Check expiration
      if (qrData.containsKey('expiresAt')) {
        DateTime expiresAt = qrData['expiresAt'] is Timestamp
            ? (qrData['expiresAt'] as Timestamp).toDate()
            : DateTime.parse(qrData['expiresAt']);

        if (DateTime.now().isAfter(expiresAt)) {
          return {
            'success': false,
            'message': 'QR code has expired',
          };
        }
      }

      // Mark as used
      await _firestore.collection('visitor_qrs').doc(qrId).update({
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // Record gate entry
      await recordGateEntry(
        residentId: qrData['residentId'] ?? residentId,
        residentName: qrData['residentName'] ?? residentName,
        entryType: 'QR_VISITOR',
        visitorName: qrData['visitorName'] ?? visitorName,
        qrCode: qrId,
        status: 'success',
      );

      return {
        'success': true,
        'residentId': qrData['residentId'] ?? residentId,
        'residentName': qrData['residentName'] ?? residentName,
        'visitorName': qrData['visitorName'] ?? visitorName,
        'message': 'Welcome ${qrData['visitorName'] ?? visitorName}! Visitor of ${qrData['residentName'] ?? residentName}',
      };

    } catch (e) {
      print("❌ Error validating visitor QR: $e");
      return {
        'success': false,
        'message': 'Error validating visitor QR: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _validateResidentQR(String qrData) async {
    try {
      print("🔍 Validating resident QR: $qrData");

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
      print("❌ Error validating resident QR: $e");
      return {
        'success': false,
        'message': 'Error validating resident QR: $e',
      };
    }
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

  Future<List<GateEntryModel>> getGateEntries() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('gate_entries')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return GateEntryModel(
          id: doc.id,
          residentId: data['residentId'] ?? '',
          residentName: data['residentName'] ?? '',
          entryType: data['entryType'] ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          visitorName: data['visitorName'],
          qrCode: data['qrCode'],
          status: data['status'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error getting gate entries: $e');
      return [];
    }
  }
}