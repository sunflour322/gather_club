import 'dart:convert';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/api_services/user_service/user.dart';
import 'package:http/http.dart' as http;

class UserRepository {
  final http.Client _client;
  final AuthProvider _authProvider;
  static const String _baseUrl = 'http://212.67.8.92:8080/users';

  UserRepository(this._client, this._authProvider);

  Future<int?> getCurrentUserId() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return null;

      final response = await _client.get(
        Uri.parse('$_baseUrl/current-id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Просто парсим число, а не JSON
        return int.tryParse(response.body);
      } else {
        print('Failed to get user ID: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user ID: $e');
      return null;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return null;

      final response = await _client.get(
        Uri.parse('$_baseUrl/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson = json.decode(response.body);
        return User.fromJson(userJson);
      } else {
        print('Failed to get user: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<String?> getUserAvatarUrl(int userId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return null;

      final response = await _client.get(
        Uri.parse('$_baseUrl/$userId/avatar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Проверяем, что URL валидный
        final url = response.body;
        if (url.startsWith('http')) {
          return url;
        }
        return null;
      } else {
        print('Failed to get avatar URL: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching avatar URL: $e');
      return null;
    }
  }

  Future<bool> updateUserAvatar(http.MultipartFile avatarFile) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return false;

      final userId = await getCurrentUserId();
      if (userId == null) return false;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/$userId/avatar'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(avatarFile);

      final response = await request.send();

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating avatar: $e');
      return false;
    }
  }

  Future<User?> setUserOnline() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return null;

      final response = await _client.put(
        Uri.parse('$_baseUrl/current/status/online'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson = json.decode(response.body);
        return User.fromJson(userJson);
      } else {
        print('Failed to set user online: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error setting user online: $e');
      return null;
    }
  }

  Future<User?> setUserOffline() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) return null;

      final response = await _client.put(
        Uri.parse('$_baseUrl/current/status/offline'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userJson = json.decode(response.body);
        return User.fromJson(userJson);
      } else {
        print('Failed to set user offline: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error setting user offline: $e');
      return null;
    }
  }
}
