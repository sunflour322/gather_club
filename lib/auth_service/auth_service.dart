import 'dart:convert';
import 'package:gather_club/auth_service/auth_models.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl = 'http://212.67.8.92:8080/auth';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _client = http.Client();

  Future<bool> login(String usernameOrEmail, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/login'),
        body: jsonEncode(LoginRequest(
          usernameOrEmail: usernameOrEmail,
          passwordHash: password, // Изменено
        ).toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _storage.write(key: 'jwt_token', value: authResponse.token);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(
      String username, String email, String passwordHash) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/register'),
        body: jsonEncode(RegisterRequest(
          username: username,
          email: email,
          passwordHash: passwordHash,
        ).toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }
}
