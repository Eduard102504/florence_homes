import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/archived_resident_model.dart';
import '../models/resident_record_model.dart';

class ArchiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String archiveCollection = 'archived_residents';
  static const String recordsCollection = 'resident_records';
  static const int autoMigrateDays = 30;

  // ============================================================
  // ARCHIVE
  // ============================================================

  /// Archive a resident (called when admin deletes a resident)
  Future<bool> archiveResident({
    required Map<String, dynamic> userData,
    required String originalId,
    String? adminUid,
    String? adminName,
    String? reason,
  }) async {
    try {
      final archiveDoc = <String, dynamic>{
        ...userData,
        'originalId': originalId,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': adminUid,
        'archivedByName': adminName,
        'deleteReason': reason,
      };
      archiveDoc.remove('plaintextPassword'); // never store sensitive data

      await _firestore.collection(archiveCollection).add(archiveDoc);
      return true;
    } catch (e) {
      print('Archive error: $e');
      return false;
    }
  }

  /// Stream of archived residents (newest first)
  Stream<List<ArchivedResidentModel>> streamArchivedResidents() {
    return _firestore
        .collection(archiveCollection)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ArchivedResidentModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
      return list;
    });
  }

  /// Restore an archived resident back into the users collection
  Future<Map<String, dynamic>> restoreResident(
      ArchivedResidentModel archived) async {
    try {
      if (archived.id == null) {
        return {
          'success': false,
          'message': 'Original ID missing in archive record',
        };
      }

      final existing =
      await _firestore.collection('users').doc(archived.id).get();
      if (existing.exists) {
        return {
          'success': false,
          'message': 'A user with this ID already exists',
        };
      }

      final userData = Map<String, dynamic>.from(archived.toMap());
      userData.remove('originalId');
      userData.remove('archivedAt');
      userData.remove('archivedBy');
      userData.remove('archivedByName');
      userData.remove('deleteReason');
      userData.remove('wasApproved');

      userData['id'] = archived.id;
      userData['createdAt'] = Timestamp.fromDate(archived.createdAt);

      await _firestore
          .collection('users')
          .doc(archived.id)
          .set(userData);

      await _firestore
          .collection(archiveCollection)
          .doc(archived.archiveId)
          .delete();

      return {
        'success': true,
        'message': '${archived.fullName} has been restored',
      };
    } catch (e) {
      print('Restore error: $e');
      return {
        'success': false,
        'message': 'Restore failed: $e',
      };
    }
  }

  /// Permanently delete ONE archived record
  /// (This is the ONLY destructive operation — explicitly triggered by admin.)
  Future<bool> permanentlyDelete(String archiveId) async {
    try {
      await _firestore.collection(archiveCollection).doc(archiveId).delete();
      return true;
    } catch (e) {
      print('Permanent delete error: $e');
      return false;
    }
  }

  /// Clear entire archive
  Future<int> clearAllArchive() async {
    try {
      final snap = await _firestore.collection(archiveCollection).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snap.docs.length;
    } catch (e) {
      print('Clear archive error: $e');
      return 0;
    }
  }

  // ============================================================
  // MOVE ARCHIVE → RECORDS
  // ============================================================

  /// Move a single archived resident to Records
  /// Called from archive screen ("Move to Records" button)
  Future<Map<String, dynamic>> moveToRecords(
      ArchivedResidentModel archived, {
        String? adminUid,
        String? adminName,
      }) async {
    try {
      if (archived.archiveId == null) {
        return {'success': false, 'message': 'Missing archive id'};
      }

      final record = ResidentRecordModel(
        originalId: archived.id,
        residentId: archived.residentId,
        fullName: archived.fullName,
        email: archived.email,
        houseNumber: archived.houseNumber,
        phoneNumber: archived.phoneNumber,
        rfidTag: archived.rfidTag,
        userType: archived.userType,
        wasApproved: archived.wasApproved,
        createdAt: archived.createdAt,
        archivedAt: archived.archivedAt,
        recordedAt: DateTime.now(),
        archivedBy: archived.archivedBy,
        archivedByName: archived.archivedByName,
        deleteReason: archived.deleteReason,
        movedBy: adminUid ?? 'system',
        movedByName: adminName ?? 'System (auto)',
      );

      // Save record
      await _firestore
          .collection(recordsCollection)
          .add(record.toMap());

      // Remove from archive
      await _firestore
          .collection(archiveCollection)
          .doc(archived.archiveId)
          .delete();

      return {
        'success': true,
        'message': '${archived.fullName} moved to Records',
      };
    } catch (e) {
      print('Move to records error: $e');
      return {
        'success': false,
        'message': 'Move failed: $e',
      };
    }
  }

  /// Auto-migrate archives older than 30 days to Records.
  /// Called silently when admin opens dashboard.
  /// ✅ NEVER DELETES — just moves.
  Future<int> migrateOldArchivesToRecords() async {
    try {
      final cutoff =
      DateTime.now().subtract(const Duration(days: autoMigrateDays));

      final snap = await _firestore
          .collection(archiveCollection)
          .where('archivedAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (snap.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      int moved = 0;

      for (final doc in snap.docs) {
        final data = doc.data();

        // Build record payload (reuse archived data)
        final recordPayload = <String, dynamic>{
          'originalId': data['originalId'],
          'residentId': data['residentId'],
          'fullName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'houseNumber': data['houseNumber'],
          'phoneNumber': data['phoneNumber'],
          'rfidTag': data['rfidTag'],
          'userType': data['userType'] ?? 'resident',
          'wasApproved': data['wasApproved'] ?? false,
          'createdAt': data['createdAt'],
          'archivedAt': data['archivedAt'],
          'recordedAt': FieldValue.serverTimestamp(),
          'archivedBy': data['archivedBy'],
          'archivedByName': data['archivedByName'],
          'deleteReason': data['deleteReason'],
          'movedBy': 'system',
          'movedByName': 'System (auto 30d)',
        };

        // Add to records collection
        final newRecordRef =
        _firestore.collection(recordsCollection).doc();
        batch.set(newRecordRef, recordPayload);

        // Remove from archive
        batch.delete(doc.reference);
        moved++;
      }

      await batch.commit();
      print('📖 Auto-migrated $moved archives to Records');
      return moved;
    } catch (e) {
      print('Auto-migration error: $e');
      return 0;
    }
  }

  // ============================================================
  // RECORDS (READ-ONLY)
  // ============================================================

  /// Stream of all records (newest first)
  Stream<List<ResidentRecordModel>> streamResidentRecords() {
    return _firestore
        .collection(recordsCollection)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ResidentRecordModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return list;
    });
  }

  /// Permanent delete from Records (only explicit admin action)
  Future<bool> permanentlyDeleteRecord(String recordId) async {
    try {
      await _firestore.collection(recordsCollection).doc(recordId).delete();
      return true;
    } catch (e) {
      print('Permanent delete record error: $e');
      return false;
    }
  }

  /// Clear entire records collection
  Future<int> clearAllRecords() async {
    try {
      final snap = await _firestore.collection(recordsCollection).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return snap.docs.length;
    } catch (e) {
      print('Clear records error: $e');
      return 0;
    }
  }
}