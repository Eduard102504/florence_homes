// ignore_for_file: body_might_complete_normally

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NFCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkNFC() async {
    bool available = false;
    try {
      available = await NfcManager.instance.isAvailable();
    } catch (e) {
      available = false;
    }
    return available;
  }

  void startScan(BuildContext context, Function(String) onTagFound) {
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        String tagId = tag.data['id'].toString();
        onTagFound(tagId);
        await NfcManager.instance.stopSession();
      },
    );
  }

  void stopScan() {
    NfcManager.instance.stopSession();
  }

  Future<bool> registerRFID(String tagId, String residentId, String residentName) async {
    bool success = false;
    try {
      await _firestore.collection('rfid_tags').doc(tagId).set({
        'residentId': residentId,
        'residentName': residentName,
        'registeredAt': DateTime.now(),
        'isActive': true,
      });

      await _firestore.collection('users').doc(residentId).update({
        'rfidTag': tagId,
      });

      success = true;
    } catch (e) {
      success = false;
    }
    return success;
  }
}