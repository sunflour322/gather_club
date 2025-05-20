import 'dart:convert';

import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:http/http.dart' as http;

class PlaceRepository {
  final http.Client _client;
  final AuthProvider _authProvider;

  PlaceRepository(this._client, this._authProvider);

  Future<List<Place>> fetchNearbyPlaces(
      double lat, double lng, double radius) async {
    final token = await _authProvider.getToken();
    print("token: $token");

    final response = await _client.get(
      Uri.parse(
          'http://212.67.8.92:8080/places/nearby?lat=$lat&lng=$lng&radiusKm=$radius'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> placesJson = json.decode(response.body);
      return placesJson.map((json) => Place.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load places: ${response.statusCode}');
    }
  }
}
