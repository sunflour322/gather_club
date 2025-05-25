import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  Future<int> getUserId() async {
    final userId = await _authService.getUserId();
    return int.parse(userId ?? '0');
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.login(usernameOrEmail, password);
      if (!success) {
        _errorMessage = 'Invalid username or password';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
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
      if (success) {
        await _authService.login(username, password);
      }
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
    try {
      await _authService.logout();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка при выходе: $e';
      notifyListeners();
      throw e;
    }
  }
}
