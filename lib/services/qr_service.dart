import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class QRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> generateVisitorQR({
    required String residentId,
    required String residentName,
    required String visitorName,
    required DateTime visitDate,
    required int validityHours,
  }) async {
    String qrId = DateTime.now().millisecondsSinceEpoch.toString();

    Map<String, dynamic> qrData = {
      'id': qrId,
      'residentId': residentId,
      'residentName': residentName,
      'visitorName': visitorName,
      'generatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(Duration(hours: validityHours)).toIso8601String(),
      'isUsed': false,
    };

    await _firestore.collection('visitor_qrs').doc(qrId).set(qrData);

    String qrString = base64.encode(utf8.encode(json.encode(qrData)));

    return qrString;
  }

  Future<File?> saveQRAsImage(String qrData, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.txt';
      final file = File(filePath);
      await file.writeAsString(qrData);
      return file;
    } catch (e) {
      print('Error saving QR: $e');
      return null;
    }
  }

  Future<void> shareQR(File qrFile, String visitorName) async {
    await Share.shareFiles(
      [qrFile.path],
      text: 'Visitor QR Code for $visitorName - Florence Homes',
    );
  }

  Future<Map<String, dynamic>> validateQR(String scannedData) async {
    try {
      String decodedString = utf8.decode(base64.decode(scannedData));
      Map<String, dynamic> qrInfo = json.decode(decodedString);

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

      if (qrData['isUsed']) {
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

      await _firestore.collection('visitor_qrs').doc(qrId).update({
        'isUsed': true,
        'usedAt': DateTime.now(),
      });

      return {
        'success': true,
        'residentId': qrData['residentId'],
        'residentName': qrData['residentName'],
        'visitorName': qrData['visitorName'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error validating QR: $e',
      };
    }
  }
}