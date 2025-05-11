import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _authService.login(usernameOrEmail, password);
      _errorMessage = success ? null : 'Invalid credentials';
      return success;
    } catch (e) {
      _errorMessage = 'Connection error';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _authService.register(username, email, password);
      _errorMessage = success ? null : 'Registration failed';
      return success;
    } catch (e) {
      _errorMessage = 'Connection error';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }
}