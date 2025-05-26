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
    print('Creating UserLocation from JSON: $json');
    try {
      return UserLocation(
        userId: json['userId'],
        latitude: json['latitude']?.toDouble() ?? 0.0,
        longitude: json['longitude']?.toDouble() ?? 0.0,
        accuracy: json['accuracy']?.toDouble(),
        altitude: json['altitude']?.toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        isPublic: json['isPublic'] ?? false,
        userAvatar: json['userAvatar'],
        userName: json['userName'],
      );
    } catch (e) {
      print('Error parsing UserLocation JSON: $e');
      rethrow;
    }
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

      // Получаем публичные локации
      print('Getting public locations...');
      final locationsResponse = await _client.get(
        Uri.parse('$_baseUrl/$userId/location/friends'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (locationsResponse.statusCode != 200) {
        throw Exception(
            'Ошибка получения локаций: ${locationsResponse.statusCode}');
      }

      final List<dynamic> locationsJson = jsonDecode(locationsResponse.body);
      print('Received ${locationsJson.length} locations');

      // Создаем Map для хранения последней локации каждого пользователя
      Map<int, UserLocation> latestLocations = {};

      // Обрабатываем все локации
      for (var locationJson in locationsJson) {
        try {
          print('Processing location: $locationJson');
          // Пропускаем свои локации
          if (locationJson['userId'] == userId) {
            print('Skipping own location');
            continue;
          }

          final location = UserLocation.fromJson(locationJson);

          // Проверяем, есть ли уже локация для этого пользователя
          if (!latestLocations.containsKey(location.userId) ||
              latestLocations[location.userId]!
                  .timestamp
                  .isBefore(location.timestamp)) {
            // Если локации нет или текущая локация новее - обновляем
            latestLocations[location.userId] = location;
          }
        } catch (e) {
          print('Error processing location data: $e');
          continue;
        }
      }

      // Получаем информацию о пользователях для каждой локации
      List<UserLocation> finalLocations = [];
      for (var location in latestLocations.values) {
        try {
          // Получаем информацию о пользователе
          final userResponse = await _client.get(
            Uri.parse('$_baseUrl/${location.userId}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (userResponse.statusCode == 200) {
            final userJson = jsonDecode(userResponse.body);
            // Создаем новую локацию с информацией о пользователе
            finalLocations.add(UserLocation(
              userId: location.userId,
              latitude: location.latitude,
              longitude: location.longitude,
              accuracy: location.accuracy,
              altitude: location.altitude,
              timestamp: location.timestamp,
              isPublic: location.isPublic,
              userName: userJson['username'],
              userAvatar: userJson['avatarUrl'],
            ));
          }
        } catch (e) {
          print('Error getting user info for location ${location.userId}: $e');
          finalLocations
              .add(location); // Добавляем локацию без информации о пользователе
        }
      }

      print('Successfully processed ${finalLocations.length} unique locations');
      return finalLocations;
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
