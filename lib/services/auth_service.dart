import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import 'email_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hardcoded admin credentials
  static const String adminEmail = 'florencehomes@gmail.com';
  static const String adminPassword = 'florence123';

  // ==================== LOGIN ====================
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      String email = identifier.trim();

      // If user typed an FHM-### ID, resolve it to the email
      if (email.toUpperCase().startsWith('FHM-')) {
        print('🔎 Resident ID login attempt: $email');
        final query = await _firestore
            .collection('users')
            .where('residentId', isEqualTo: email.toUpperCase())
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          return {
            'success': false,
            'message': 'Resident ID not found',
          };
        }

        final docData = query.docs.first.data() as Map<String, dynamic>;
        email = (docData['authEmail'] as String?) ??
            (docData['email'] as String?) ??
            '';
        print('✅ Resolved Resident ID to auth email: $email');
      }

      // Check if it's the hardcoded admin account
      if (email.toLowerCase().trim() == adminEmail.toLowerCase() &&
          password == adminPassword) {
        print('Attempting admin login...');

        UserCredential? userCredential;
        bool isNewAdmin = false;

        try {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
          print('Admin signed in successfully');
        } catch (e) {
          print('Admin not found, creating new account...');
          try {
            userCredential = await _auth.createUserWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );
            isNewAdmin = true;
            print('Admin account created successfully');
          } catch (createError) {
            print('Error creating admin: $createError');
            return {
              'success': false,
              'message': 'Error creating admin account: $createError',
            };
          }
        }

        if (userCredential != null) {
          String userId = userCredential.user!.uid;
          DocumentSnapshot adminDoc =
          await _firestore.collection('users').doc(userId).get();

          if (!adminDoc.exists || isNewAdmin) {
            UserModel adminUser = UserModel(
              id: userId,
              email: adminEmail,
              fullName: 'System Administrator',
              userType: 'admin',
              isApproved: true,
              createdAt: DateTime.now(),
            );
            await _firestore
                .collection('users')
                .doc(userId)
                .set(adminUser.toMap());

            return {
              'success': true,
              'user': adminUser,
            };
          } else {
            UserModel user = UserModel.fromMap(
                userId, adminDoc.data() as Map<String, dynamic>);
            return {
              'success': true,
              'user': user,
            };
          }
        }
      }

      // Regular user login
      print('Regular user login attempt with: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String userId = userCredential.user!.uid;
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User profile not found. Please contact administrator.',
        };
      }

      bool isApproved = userDoc.get('isApproved');
      if (!isApproved) {
        await _auth.signOut();
        return {
          'success': false,
          'message':
          'Your account is pending admin approval. Please wait for confirmation.',
        };
      }

      UserModel user = UserModel.fromMap(
          userId, userDoc.data() as Map<String, dynamic>);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Invalid credentials',
      };
    }
  }

  // ==================== RESIDENT ID GENERATION ====================
  Future<String> _generateResidentId() async {
    final counterRef = _firestore.collection('system').doc('counters');

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int nextNumber = 1;

      if (snapshot.exists) {
        nextNumber = ((snapshot.data()?['residentCounter'] ?? 0) as int) + 1;
      }

      transaction.set(
        counterRef,
        {'residentCounter': nextNumber},
        SetOptions(merge: true),
      );

      return 'FHM-${nextNumber.toString().padLeft(3, '0')}';
    });
  }

  // ==================== MANUAL REGISTRATION (ADMIN) ====================
  Future<Map<String, dynamic>> registerResidentManually({
    required String fullName,
    required String password,
    required String houseNumber,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final residentId = await _generateResidentId();
      print('🆔 Generated Resident ID: $residentId');

      String? normalizedEmail = email?.trim().toLowerCase();
      bool hasRealEmail =
          normalizedEmail != null && normalizedEmail.isNotEmpty;

      String authEmail;
      if (hasRealEmail) {
        if (normalizedEmail == adminEmail.toLowerCase()) {
          return {
            'success': false,
            'message': 'This email is reserved for system administrator.',
          };
        }
        List<String> signInMethods =
        await _auth.fetchSignInMethodsForEmail(normalizedEmail);
        if (signInMethods.isNotEmpty) {
          return {
            'success': false,
            'message': 'An account with this email already exists.',
          };
        }
        authEmail = normalizedEmail;
      } else {
        authEmail = '${residentId.toLowerCase()}@florencehomes.local';
      }

      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      String userId = userCredential.user!.uid;
      print('✅ Auth user created: $userId ($authEmail)');

      UserModel user = UserModel(
        id: userId,
        residentId: residentId,
        email: hasRealEmail ? authEmail : '',
        fullName: fullName,
        userType: 'resident',
        isApproved: false,
        createdAt: DateTime.now(),
        houseNumber: houseNumber,
        phoneNumber: phoneNumber,
      );

      await _firestore.collection('users').doc(userId).set({
        ...user.toMap(),
        'authEmail': authEmail,
        'hasRealEmail': hasRealEmail,
        'isManualRegistration': true,
        'plaintextPassword': password,
      });
      print('✅ Firestore user created for: $residentId');

      await _auth.signOut();

      return {
        'success': true,
        'message': 'Resident added. Pending admin approval.',
        'userId': userId,
        'residentId': residentId,
        'password': password,
      };
    } catch (e) {
      print('❌ Manual registration error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ==================== SELF-REGISTRATION (EMAIL VERIFIED) ====================
  // 🆕 Also generates FHM ID and stores password for the approval email
  Future<Map<String, dynamic>> registerUser(
      String email,
      String password,
      String fullName,
      String userType,
      String? houseNumber,
      String? phoneNumber,
      ) async {
    try {
      String normalizedEmail = email.trim().toLowerCase();

      if (normalizedEmail == adminEmail.toLowerCase()) {
        return {
          'success': false,
          'message': 'This email is reserved for system administrator.',
        };
      }

      List<String> signInMethods =
      await _auth.fetchSignInMethodsForEmail(normalizedEmail);
      if (signInMethods.isNotEmpty) {
        return {
          'success': false,
          'message': 'An account with this email already exists.',
        };
      }

      // 🆕 Generate Resident ID for self-registered users too
      final residentId = await _generateResidentId();
      print('🆔 Generated Resident ID (self-reg): $residentId');

      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      print('✅ Auth user created: ${userCredential.user!.uid}');

      String userId = userCredential.user!.uid;

      UserModel user = UserModel(
        id: userId,
        residentId: residentId,
        email: normalizedEmail,
        fullName: fullName,
        userType: 'resident',
        isApproved: false,
        createdAt: DateTime.now(),
        houseNumber: houseNumber,
        phoneNumber: phoneNumber,
      );

      await _firestore.collection('users').doc(userId).set({
        ...user.toMap(),
        'authEmail': normalizedEmail,
        'hasRealEmail': true,
        'isManualRegistration': false,
        'plaintextPassword': password, // so we can email it on approval
      });
      print('✅ Firestore user created for: $normalizedEmail');

      await _auth.signOut();

      return {
        'success': true,
        'message': 'Registration successful. Waiting for admin approval.',
        'userId': userId,
        'residentId': residentId,
      };
    } catch (e) {
      print('❌ Registration error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ==================== PASSWORD RESET ====================
  Future<Map<String, dynamic>> sendPasswordResetCode(String email) async {
    try {
      String normalizedEmail = email.trim().toLowerCase();

      QuerySnapshot approvedCheck = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (approvedCheck.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No account found with this email address',
        };
      }

      Map<String, dynamic> userData =
      approvedCheck.docs.first.data() as Map<String, dynamic>;
      bool isApproved = userData['isApproved'] ?? false;

      if (!isApproved) {
        return {
          'success': false,
          'message':
          'Your account is pending admin approval. Please wait for approval before resetting password.',
        };
      }

      String code = (100000 + Random().nextInt(900000)).toString();

      await _firestore
          .collection('password_resets')
          .doc(normalizedEmail)
          .set({
        'code': code,
        'email': normalizedEmail,
        'createdAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
        'isUsed': false,
      });

      bool emailSent =
      await EmailService.sendVerificationCode(normalizedEmail, code);

      if (emailSent) {
        return {
          'success': true,
          'message':
          'Verification code sent to your email. Please check your inbox.',
          'email': normalizedEmail,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to send email. Please try again.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    try {
      String normalizedEmail = email.trim().toLowerCase();
      DocumentSnapshot doc = await _firestore
          .collection('password_resets')
          .doc(normalizedEmail)
          .get();

      if (!doc.exists) {
        return {'success': false, 'message': 'No reset request found'};
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['code'] != code) {
        return {'success': false, 'message': 'Invalid code'};
      }
      if (data['isUsed'] == true) {
        return {'success': false, 'message': 'Code has already been used'};
      }

      DateTime expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        return {'success': false, 'message': 'Code has expired'};
      }

      await _firestore
          .collection('password_resets')
          .doc(normalizedEmail)
          .update({'isUsed': true});

      await _auth.sendPasswordResetEmail(email: normalizedEmail);

      return {
        'success': true,
        'message':
        'Code verified! Password reset email sent to your inbox.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==================== ADMIN FUNCTIONS ====================
  Future<bool> approveUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
      });
      return true;
    } catch (e) {
      print('Error approving user: $e');
      return false;
    }
  }

  Future<bool> rejectUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      User? user = _auth.currentUser;
      if (user != null && user.uid == userId) {
        await user.delete();
      }
      return true;
    } catch (e) {
      print('Error rejecting user: $e');
      return false;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromMap(
            userId, userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<List<UserModel>> getPendingUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .where('isApproved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return UserModel.fromMap(
            doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting pending users: $e');
      return [];
    }
  }

  Future<List<UserModel>> getAllResidents() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'resident')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        return UserModel.fromMap(
            doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error getting residents: $e');
      return [];
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  bool isLoggedIn() {
    return _auth.currentUser != null;
  }
}