// ignore_for_file: body_might_complete_normally

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BackgroundNFCService {
  static final BackgroundNFCService _instance = BackgroundNFCService._internal();
  factory BackgroundNFCService() => _instance;
  BackgroundNFCService._internal();

  bool _isScanning = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Function(Map<String, dynamic>)? _onTagDetected;

  bool get isScanning => _isScanning;

  void startScanning(Function(Map<String, dynamic>) onTagDetected) {
    if (_isScanning) return;

    _isScanning = true;
    _onTagDetected = onTagDetected;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        String tagId = tag.data['id'].toString();
        Map<String, dynamic> result = await _processTag(tagId);
        if (_onTagDetected != null) {
          _onTagDetected!(result);
        }
      },
      onError: (error) async {
        print('NFC Error: $error');
        // Return a Future to satisfy the return type
        return;
      },
    );
  }

  void stopScanning() {
    _isScanning = false;
    _onTagDetected = null;
    NfcManager.instance.stopSession();
  }

  Future<Map<String, dynamic>> _processTag(String tagId) async {
    try {
      DocumentSnapshot rfidDoc = await _firestore
          .collection('rfid_tags')
          .doc(tagId)
          .get();

      if (!rfidDoc.exists) {
        return {
          'success': false,
          'message': 'Invalid RFID Card',
          'tagId': tagId,
        };
      }

      String residentId = rfidDoc.get('residentId');
      DocumentSnapshot residentDoc = await _firestore
          .collection('users')
          .doc(residentId)
          .get();

      if (!residentDoc.exists) {
        return {
          'success': false,
          'message': 'Resident not found',
          'tagId': tagId,
        };
      }

      bool isApproved = residentDoc.get('isApproved');
      if (!isApproved) {
        return {
          'success': false,
          'message': 'Account pending approval',
          'tagId': tagId,
        };
      }

      String residentName = residentDoc.get('fullName');
      String houseNumber = residentDoc.get('houseNumber');

      await _firestore.collection('gate_entries').add({
        'residentId': residentId,
        'residentName': residentName,
        'entryType': 'rfid',
        'timestamp': DateTime.now(),
        'status': 'entry',
        'rfidTag': tagId,
      });

      await _firestore.collection('users').doc(residentId).update({
        'lastAccess': DateTime.now(),
      });

      return {
        'success': true,
        'residentId': residentId,
        'residentName': residentName,
        'houseNumber': houseNumber,
        'tagId': tagId,
        'message': 'Access Granted',
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'tagId': tagId,
      };
    }
  }
}