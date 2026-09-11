import 'package:cloud_firestore/cloud_firestore.dart';

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
        'timestamp': DateTime.now().toIso8601String(),
        'visitorName': visitorName,
        'qrCode': qrCode,
        'status': status,
      });

      // Update last access for resident
      await _firestore.collection('users').doc(residentId).update({
        'lastAccess': DateTime.now().toIso8601String(),
        'lastAccessType': entryType,
      });

      print('✅ Entry recorded successfully');
      return true;
    } catch (e) {
      print('❌ Error recording entry: $e');
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

      // Record entry
      await recordGateEntry(
        residentId: residentId,
        residentName: residentDoc.get('fullName'),
        entryType: 'rfid',
        status: 'entry',
      );

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

  Future<List<Map<String, dynamic>>> getGateEntries() async {
    QuerySnapshot snapshot = await _firestore
        .collection('gate_entries')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}