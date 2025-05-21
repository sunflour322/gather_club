import 'dart:convert';
import 'dart:io';

import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:http/http.dart' as http;

class PlaceRepository {
  final AuthProvider _authProvider;

  PlaceRepository(this._authProvider);

  Future<List<PlaceImage>> fetchPlaceImages(int placeId) async {
    final token = await _authProvider.getToken();
    final response = await http.get(
      Uri.parse('http://212.67.8.92:8080/places/$placeId/images'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> imagesJson = json.decode(response.body);
      return imagesJson.map((json) => PlaceImage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load place images');
    }
  }

  Future<PlaceImage> uploadPlaceImage(int placeId, File imageFile) async {
    final token = await _authProvider.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://212.67.8.92:8080/places/$placeId/images/add'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    ));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return PlaceImage.fromJson(json.decode(responseData));
    } else {
      throw Exception('Failed to upload image');
    }
  }

  Future<Reward?> claimVisitReward(int placeId) async {
    // Реали
    //зация получения награды
  }
  Future<void> rateImage(int imageId, bool isLike) async {
    // Реализация API вызова для оценки изображения
  }
}
