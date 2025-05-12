import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _baseUrl = 'http://212.67.8.92:8080';

  Future<http.Response> get(String path) async {
    final token = await _storage.read(key: 'jwt_token');
    return _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> post(String path, dynamic body) async {
    final token = await _storage.read(key: 'jwt_token');
    return _client.post(
      Uri.parse('$_baseUrl$path'),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }
}
