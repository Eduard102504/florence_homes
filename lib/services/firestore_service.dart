// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/gate_entry_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User operations
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  // RFID operations
  Future<bool> registerRFID({
    required String rfidData,
    required String residentId,
  }) async {
    try {
      await _firestore.collection('rfid_tags').doc(rfidData).set({
        'residentId': residentId,
        'assignedAt': DateTime.now(),
        'isActive': true,
      });

      await _firestore.collection('users').doc(residentId).update({
        'rfidTag': rfidData,
      });

      return true;
    } catch (e) {
      print('Error registering RFID: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getRFIDData(String rfidData) async {
    DocumentSnapshot doc = await _firestore.collection('rfid_tags').doc(rfidData).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // Gate entry operations
  Future<void> addGateEntry(GateEntryModel entry) async {
    await _firestore.collection('gate_entries').add(entry.toMap());
  }

  Stream<List<GateEntryModel>> streamGateEntries({
    String? residentId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection('gate_entries').orderBy('timestamp', descending: true);

    if (residentId != null) {
      query = query.where('residentId', isEqualTo: residentId);
    }

    if (startDate != null && endDate != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Visitor QR operations
  Future<void> createVisitorQR(Map<String, dynamic> qrData) async {
    await _firestore.collection('visitor_qrs').doc(qrData['id']).set(qrData);
  }

  Future<Map<String, dynamic>?> getVisitorQR(String qrId) async {
    DocumentSnapshot doc = await _firestore.collection('visitor_qrs').doc(qrId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> markQRAsUsed(String qrId) async {
    await _firestore.collection('visitor_qrs').doc(qrId).update({
      'isUsed': true,
      'usedAt': DateTime.now(),
    });
  }

  // Statistics and reports
  Future<Map<String, dynamic>> getDailyStats(DateTime date) async {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot snapshot = await _firestore
        .collection('gate_entries')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();

    List<GateEntryModel> entries = snapshot.docs.map((doc) {
      return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();

    return {
      'total': entries.length,
      'rfid': entries.where((e) => e.entryType == 'rfid').length,
      'qr': entries.where((e) => e.entryType == 'qr').length,
      'manual': entries.where((e) => e.entryType == 'manual').length,
      'visitors': entries.where((e) => e.visitorName != null).length,
    };
  }

  // Bulk operations for reports
  Future<List<GateEntryModel>> getEntriesForReport(
      DateTime startDate,
      DateTime endDate, {
        String? residentId,
        String? entryType,
      }) async {
    Query query = _firestore
        .collection('gate_entries')
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThanOrEqualTo: endDate)
        .orderBy('timestamp', descending: true);

    if (residentId != null) {
      query = query.where('residentId', isEqualTo: residentId);
    }

    if (entryType != null) {
      query = query.where('entryType', isEqualTo: entryType);
    }

    QuerySnapshot snapshot = await query.get();

    return snapshot.docs.map((doc) {
      return GateEntryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }
}
