import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAdmin => _currentUser?.userType == 'admin';
  bool get isResident => _currentUser?.userType == 'resident';

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(email, password);

    _isLoading = false;

    if (result['success']) {
      _currentUser = result['user'];
      notifyListeners();
      return true;
    } else {
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String userType,
    String? houseNumber,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.registerUser(
      email,
      password,
      fullName,
      userType,
      houseNumber,
      phoneNumber,
    );

    _isLoading = false;
    notifyListeners();

    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}