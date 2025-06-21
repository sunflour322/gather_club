import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gather_club/api_services/user_service/friend.dart';

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

    print('Отправка запроса в друзья: $url');

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
      final List<Friend> friends = [];

      for (var json in friendsJson) {
        final userId = json['user2Id'] == currentUserId
            ? json['user1Id']
            : json['user2Id'];
        final userInfo = await getUserInfo(userId, token);
        json['username'] = userInfo['username'];
        json['avatarUrl'] = userInfo['avatarUrl'];
        json['currentUserId'] = currentUserId;
        friends.add(Friend.fromJson(json));
      }

      return friends;
    } else {
      throw Exception('Не удалось получить список друзей');
    }
  }

  Future<List<Friend>> getIncomingRequests(String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.get(
      Uri.parse('$_baseUrl/friendships/$currentUserId/incoming'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /friendships/incoming Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> requestsJson = jsonDecode(response.body);
      final List<Friend> requests = [];

      for (var json in requestsJson) {
        final userInfo = await getUserInfo(json['user1Id'], token);
        json['username'] = userInfo['username'];
        json['avatarUrl'] = userInfo['avatarUrl'];
        json['currentUserId'] = currentUserId;
        requests.add(Friend.fromJson(json));
      }

      return requests;
    } else {
      throw Exception('Не удалось получить список входящих запросов');
    }
  }

  Future<List<Friend>> getOutgoingRequests(String token) async {
    final currentUserId = await getCurrentUserId(token);
    final response = await _client.get(
      Uri.parse('$_baseUrl/friendships/$currentUserId/outgoing'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /friendships/outgoing Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> requestsJson = jsonDecode(response.body);
      final List<Friend> requests = [];

      for (var json in requestsJson) {
        final userInfo = await getUserInfo(json['user2Id'], token);
        json['username'] = userInfo['username'];
        json['avatarUrl'] = userInfo['avatarUrl'];
        json['currentUserId'] = currentUserId;
        requests.add(Friend.fromJson(json));
      }

      return requests;
    } else {
      throw Exception('Не удалось получить список исходящих запросов');
    }
  }

  Future<Map<String, dynamic>> getUserInfo(int userId, String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: _getAuthHeaders(token),
    );

    print(
        'GET /users/$userId Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Не удалось получить информацию о пользователе');
    }
  }

  Future<void> deleteFriend(int friendshipId, String token) async {
    final currentUserId = await getCurrentUserId(token);

    // Сначала получаем информацию о дружбе, чтобы узнать ID друга
    final friendsResponse = await _client.get(
      Uri.parse('$_baseUrl/friendships/$currentUserId/friends'),
      headers: _getAuthHeaders(token),
    );

    if (friendsResponse.statusCode != 200) {
      throw Exception('Не удалось получить информацию о друзьях');
    }

    final List<dynamic> friendships = jsonDecode(friendsResponse.body);
    final friendship = friendships.firstWhere(
      (f) => f['id'] == friendshipId || f['friendshipId'] == friendshipId,
      orElse: () => throw Exception('Дружба не найдена'),
    );

    final friendId = friendship['user2Id'] == currentUserId
        ? friendship['user1Id']
        : friendship['user2Id'];

    final response = await _client.delete(
      Uri.parse('$_baseUrl/friendships/$currentUserId/friends/$friendId'),
      headers: _getAuthHeaders(token),
    );

    print(
        'DELETE /friendships/friends Response: ${response.statusCode} - ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось удалить друга. Статус: ${response.statusCode}, Ответ: ${response.body}');
    }
  }
}
