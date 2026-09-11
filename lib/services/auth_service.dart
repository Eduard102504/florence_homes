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
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Check if it's the hardcoded admin account
      if (email.toLowerCase().trim() == adminEmail.toLowerCase() && password == adminPassword) {
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
          DocumentSnapshot adminDoc = await _firestore.collection('users').doc(userId).get();

          if (!adminDoc.exists || isNewAdmin) {
            print('Creating admin in Firestore...');
            UserModel adminUser = UserModel(
              id: userId,
              email: adminEmail,
              fullName: 'System Administrator',
              userType: 'admin',
              isApproved: true,
              createdAt: DateTime.now(),
            );
            await _firestore.collection('users').doc(userId).set(adminUser.toMap());
            print('Admin created in Firestore');

            return {
              'success': true,
              'user': adminUser,
            };
          } else {
            UserModel user = UserModel.fromMap(userId, adminDoc.data() as Map<String, dynamic>);
            return {
              'success': true,
              'user': user,
            };
          }
        }
      }

      // Regular user login
      print('Regular user login attempt...');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String userId = userCredential.user!.uid;
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User profile not found. Please contact administrator.',
        };
      }

      bool isApproved = userDoc.get('isApproved');
      String userType = userDoc.get('userType');

      if (!isApproved) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Your account is pending admin approval. Please wait for confirmation.',
        };
      }

      UserModel user = UserModel.fromMap(userId, userDoc.data() as Map<String, dynamic>);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Invalid email or password',
      };
    }
  }

  // ==================== REGISTRATION ====================
  Future<Map<String, dynamic>> registerUser(
      String email,
      String password,
      String fullName,
      String userType,
      String? houseNumber,
      String? phoneNumber,
      ) async {
    try {
      if (email.toLowerCase().trim() == adminEmail.toLowerCase()) {
        return {
          'success': false,
          'message': 'This email is reserved for system administrator.',
        };
      }

      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        return {
          'success': false,
          'message': 'An account with this email already exists.',
        };
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Auth user created: ${userCredential.user!.uid}');

      String userId = userCredential.user!.uid;

      UserModel user = UserModel(
        id: userId,
        email: email,
        fullName: fullName,
        userType: 'resident',
        isApproved: false,
        createdAt: DateTime.now(),
        houseNumber: houseNumber,
        phoneNumber: phoneNumber,
      );

      await _firestore.collection('users').doc(userId).set(user.toMap());
      print('✅ Firestore user created for: $email');

      await _auth.signOut();
      print('✅ Signed out user - pending approval required');

      return {
        'success': true,
        'message': 'Registration successful. Waiting for admin approval.',
        'userId': userId,
      };
    } catch (e) {
      print('❌ Registration error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ==================== PASSWORD RESET WITH OTP ====================

  // Step 1: Send password reset code (OTP)
  Future<Map<String, dynamic>> sendPasswordResetCode(String email) async {
    try {
      print('🔍 Checking account for email: $email');

      String normalizedEmail = email.trim().toLowerCase();

      // Check if user exists and is APPROVED in Firestore
      QuerySnapshot approvedCheck = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      print('📋 Firestore users found: ${approvedCheck.docs.length}');

      if (approvedCheck.docs.isEmpty) {
        print('❌ No account found for email: $email');
        return {
          'success': false,
          'message': 'No account found with this email address',
        };
      }

      // Check if user is approved
      Map<String, dynamic> userData = approvedCheck.docs.first.data() as Map<String, dynamic>;
      bool isApproved = userData['isApproved'] ?? false;

      if (!isApproved) {
        print('⚠️ Account exists but NOT APPROVED yet');
        return {
          'success': false,
          'message': 'Your account is pending admin approval. Please wait for approval before resetting password.',
        };
      }

      print('✅ Approved account found! Generating OTP...');

      // Generate 6-digit code
      String code = (100000 + Random().nextInt(900000)).toString();

      // Store code in Firestore
      await _firestore.collection('password_resets').doc(normalizedEmail).set({
        'code': code,
        'email': normalizedEmail,
        'createdAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
        'isUsed': false,
      });

      // Send email with OTP code
      bool emailSent = await EmailService.sendVerificationCode(normalizedEmail, code);

      if (emailSent) {
        print('✅ OTP sent to approved user: $email');
        return {
          'success': true,
          'message': 'Verification code sent to your email. Please check your inbox (and spam folder).',
          'email': normalizedEmail,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to send email. Please try again.',
        };
      }
    } catch (e) {
      print('❌ Error sending reset code: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Step 2: Verify reset code and send Firebase reset email
  Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    try {
      String normalizedEmail = email.trim().toLowerCase();
      DocumentSnapshot doc = await _firestore.collection('password_resets').doc(normalizedEmail).get();

      if (!doc.exists) {
        return {
          'success': false,
          'message': 'No reset request found',
        };
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['code'] != code) {
        return {
          'success': false,
          'message': 'Invalid code',
        };
      }

      if (data['isUsed'] == true) {
        return {
          'success': false,
          'message': 'Code has already been used',
        };
      }

      DateTime expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'Code has expired',
        };
      }

      // Mark code as used
      await _firestore.collection('password_resets').doc(normalizedEmail).update({
        'isUsed': true,
      });

      // Send Firebase password reset email (this works reliably)
      await _auth.sendPasswordResetEmail(email: normalizedEmail);

      return {
        'success': true,
        'message': 'Code verified! Password reset email sent to your inbox. Please check your spam folder if you don\'t see it.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
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
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
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
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromMap(userId, userDoc.data() as Map<String, dynamic>);
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
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
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
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
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