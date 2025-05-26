import 'dart:convert';
import 'package:gather_club/auth_service/auth_models.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl = 'http://212.67.8.92:8080/auth';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  http.Client _client = http.Client();

  // Метод для получения клиента
  http.Client get _httpClient {
    if (_client.hashCode == 0) {
      _client = http.Client();
    }
    return _client;
  }

  Future<bool> login(String usernameOrEmail, String passwordHash) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/login'),
        body: jsonEncode(LoginRequest(
          usernameOrEmail: usernameOrEmail,
          passwordHash: passwordHash,
        ).toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        print('Auth response: ${response.body}');
        print('Parsed userId: ${authResponse.userId}');
        await _storage.write(key: 'jwt_token', value: authResponse.token);
        await _storage.write(
            key: 'userId', value: authResponse.userId.toString());
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
      final response = await _httpClient.post(
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

  Future<String?> getUserId() async {
    return await _storage.read(key: 'userId');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    try {
      await _storage.deleteAll();
      _client.close();
      // Создаем новый клиент
      _client = http.Client();
    } catch (e) {
      print('Error during logout: $e');
      throw e;
    }
  }
}
