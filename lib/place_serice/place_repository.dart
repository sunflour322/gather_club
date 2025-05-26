import 'dart:convert';
import 'dart:io';

import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:http/http.dart' as http;

class PlaceRepository {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080/places';

  PlaceRepository(this._authProvider);

  Future<List<PlaceImage>> fetchPlaceImages(int placeId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await http.get(
        Uri.parse('http://212.67.8.92:8080/place-images/place/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> imagesJson = jsonDecode(response.body);
        return imagesJson
            .map((json) => PlaceImage.fromJson(json))
            .where((image) => image.isApproved)
            .toList();
      } else {
        throw Exception('Ошибка загрузки изображений: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching place images: $e');
      return [];
    }
  }

  Future<PlaceImage> uploadPlaceImage(int placeId, File imageFile) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      if (!await imageFile.exists()) {
        throw Exception('Файл изображения не существует');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/$placeId/images/add'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      try {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ));
      } catch (e) {
        throw Exception('Ошибка при чтении файла изображения: $e');
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Превышено время ожидания загрузки');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          return PlaceImage.fromJson(json.decode(response.body));
        } catch (e) {
          throw Exception('Ошибка при разборе ответа сервера: $e');
        }
      } else {
        throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<Reward?> claimVisitReward(int placeId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await http.post(
        Uri.parse('$_baseUrl/$placeId/claim-reward'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> rewardJson = json.decode(response.body);
        return Reward(
          amount: rewardJson['amount'],
          currency: rewardJson['currency'],
        );
      } else if (response.statusCode == 404) {
        return null; // Награда не доступна
      } else {
        throw Exception('Ошибка получения награды: ${response.statusCode}');
      }
    } catch (e) {
      print('Error claiming reward: $e');
      rethrow;
    }
  }

  Future<void> rateImage(int imageId, bool isLike) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final userId = await _authProvider.getUserId();
      final endpoint = isLike ? 'like' : 'dislike';

      final response = await http.post(
        Uri.parse(
            'http://212.67.8.92:8080/place-images/$userId/$imageId/$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка при оценке изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error rating image: $e');
      rethrow;
    }
  }
}
