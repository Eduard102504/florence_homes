// lib/services/auth_service.dart - Complete file with auto admin creation
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hardcoded admin credentials
  static const String adminEmail = 'florencehomes@gmail.com';
  static const String adminPassword = 'florence123';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Check if it's the hardcoded admin account
      if (email.toLowerCase().trim() == adminEmail.toLowerCase() && password == adminPassword) {
        print('Attempting admin login...');

        // Try to sign in with Firebase
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
          // Admin doesn't exist, create it
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

          // Check if admin exists in Firestore
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

  // Register new user (residents only)
  Future<Map<String, dynamic>> registerUser(
      String email,
      String password,
      String fullName,
      String userType,
      String? houseNumber,
      String? phoneNumber,
      ) async {
    try {
      // Check if trying to register as admin
      if (email.toLowerCase().trim() == adminEmail.toLowerCase()) {
        return {
          'success': false,
          'message': 'This email is reserved for system administrator.',
        };
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

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

      return {
        'success': true,
        'message': 'Registration successful. Waiting for admin approval.',
        'userId': userId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Approve user (admin only)
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

  // Reject user (admin only)
  Future<bool> rejectUser(String userId, String reason) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      await _firestore.collection('users').doc(userId).delete();

      // Delete from Authentication
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

  // Get user by ID
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

  // Get all pending users (for admin)
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

  // Get all residents (for admin)
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

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Error sending password reset: $e');
      return false;
    }
  }
}