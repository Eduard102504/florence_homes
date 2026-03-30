// lib/services/gate_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gate_entry_model.dart';

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
    return {
      'success': true,
      'message': 'QR code scanned',
    };
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
}
