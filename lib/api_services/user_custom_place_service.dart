import 'dart:convert';
import 'package:http/http.dart' as http;
import 'place_serice/user_custom_place.dart';
import 'auth_service/auth_provider.dart';

class UserCustomPlaceService {
  final AuthProvider _authProvider;
  final String baseUrl = 'http://212.67.8.92:8080/user-places';

  UserCustomPlaceService(this._authProvider);

  Future<UserCustomPlace> createPlace(int userId, UserCustomPlace place) async {
    final token = await _authProvider.getToken();
    print('Creating place with token: $token');
    print('Request body: ${jsonEncode(place.toJson())}');

    final response = await http.post(
      Uri.parse('$baseUrl/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(place.toJson()),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      return UserCustomPlace.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
          'Failed to create place: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<UserCustomPlace>> getAllPlaces(int userId) async {
    final token = await _authProvider.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> placesJson = jsonDecode(response.body);
      return placesJson.map((json) => UserCustomPlace.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load places: ${response.statusCode}');
    }
  }

  Future<List<UserCustomPlace>> getPlacesInArea(
    int userId,
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  ) async {
    final token = await _authProvider.getToken();
    final response = await http.get(
      Uri.parse(
        '$baseUrl/$userId/area?minLat=$minLat&maxLat=$maxLat&minLon=$minLon&maxLon=$maxLon',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> placesJson = jsonDecode(response.body);
      return placesJson.map((json) => UserCustomPlace.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load places in area: ${response.statusCode}');
    }
  }

  Future<void> deletePlace(int userId, int placeId) async {
    final token = await _authProvider.getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/$userId/$placeId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete place: ${response.statusCode}');
    }
  }
}
