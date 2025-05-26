import 'dart:convert';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:http/http.dart' as http;

class UserLocation {
  final int userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final DateTime timestamp;
  final bool isPublic;
  final String? userAvatar;
  final String? userName;

  UserLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    required this.timestamp,
    required this.isPublic,
    this.userAvatar,
    this.userName,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      userId: json['userId'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      altitude: json['altitude'],
      timestamp: DateTime.parse(json['timestamp']),
      isPublic: json['isPublic'] ?? false,
      userAvatar: json['userAvatar'],
      userName: json['userName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'isPublic': isPublic,
    };
  }
}

class UserLocationService {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080/users';
  final http.Client _client = http.Client();

  UserLocationService(this._authProvider);

  Future<UserLocation> updateLocation(int userId, UserLocation location) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse('$_baseUrl/$userId/location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(location.toJson()),
      );

      if (response.statusCode == 200) {
        return UserLocation.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Ошибка обновления местоположения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating location: $e');
      rethrow;
    }
  }

  Future<List<UserLocation>> getFriendsLocations() async {
    try {
      print('Getting friends locations...');
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      print('Making request to: $_baseUrl/$userId/friends/locations');
      final response = await _client.get(
        Uri.parse('$_baseUrl/$userId/friends/locations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'Friends locations response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> locationsJson = jsonDecode(response.body);
        print('Parsed locations JSON: $locationsJson');
        final locations =
            locationsJson.map((json) => UserLocation.fromJson(json)).toList();
        print('Converted to UserLocation objects: $locations');
        return locations;
      } else {
        throw Exception(
            'Ошибка получения местоположений друзей: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting friends locations: $e');
      rethrow;
    }
  }

  Future<UserLocation?> getLastLocation(int userId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_baseUrl/$userId/location/last'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return UserLocation.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
            'Ошибка получения местоположения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting last location: $e');
      rethrow;
    }
  }
}
