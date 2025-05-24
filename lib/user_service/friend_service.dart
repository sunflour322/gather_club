import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gather_club/user_service/friend.dart';

class FriendService {
  final http.Client _client;
  final String _baseUrl = 'http://212.67.8.92:8080';

  FriendService(this._client);

  Map<String, String> _getAuthHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<int> getCurrentUserId(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/users/current-id'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /users/current-id Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          'Не удалось получить ID текущего пользователя. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/users/all'),
      headers: _getAuthHeaders(token),
    );

    print('GET /users Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> usersJson = jsonDecode(response.body);
      return usersJson.cast<Map<String, dynamic>>();
    } else {
      throw Exception(
          'Не удалось получить список пользователей. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<Friend> sendFriendRequest(int friendId, String token) async {
    final currentUserId = await getCurrentUserId(token);
    final url =
        Uri.parse('$_baseUrl/friendships/request/$currentUserId/$friendId');
    print('Отправка POST запроса на $url');
    print('Заголовки: ${_getAuthHeaders(token)}');

    final response = await _client.post(
      url,
      headers: _getAuthHeaders(token),
    );

    print(
        'POST /friendships/request Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return Friend.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
          'Не удалось отправить запрос в друзья. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<Friend> acceptFriendRequest(int friendshipId, String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.post(
      Uri.parse('$_baseUrl/friendships/$currentUserId/$friendshipId/accept'),
      headers: _getAuthHeaders(token),
    );

    print(
        'POST /friendships/accept Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return Friend.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
          'Не удалось принять запрос в друзья. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<Friend> rejectFriendRequest(int friendshipId, String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.post(
      Uri.parse('$_baseUrl/friendships/$currentUserId/$friendshipId/reject'),
      headers: _getAuthHeaders(token),
    );

    print(
        'POST /friendships/reject Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return Friend.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
          'Не удалось отклонить запрос в друзья. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<List<Friend>> getAllFriends(String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.get(
      Uri.parse('$_baseUrl/friendships/$currentUserId/friends'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /friendships/friends Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> friendsJson = jsonDecode(response.body);
      return friendsJson.map((json) => Friend.fromJson(json)).toList();
    } else {
      throw Exception(
          'Не удалось получить список друзей. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }

  Future<List<Friend>> getPendingRequests(String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.get(
      Uri.parse('$_baseUrl/friendships/$currentUserId/pending'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /friendships/pending Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> requestsJson = jsonDecode(response.body);
      return requestsJson.map((json) => Friend.fromJson(json)).toList();
    } else {
      throw Exception(
          'Не удалось получить список запросов в друзья. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }
}
