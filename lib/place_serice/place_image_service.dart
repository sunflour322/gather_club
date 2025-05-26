import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/place_serice/place.dart';

class PlaceImageService {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080/place-images';
  final http.Client _client = http.Client();

  PlaceImageService(this._authProvider);

  Future<List<PlaceImage>> getPlaceImages(int placeId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_baseUrl/place/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> imagesJson = jsonDecode(response.body);
        // Фильтруем только одобренные изображения
        return imagesJson
            .map((json) => PlaceImage.fromJson(json))
            .where((image) => image.isApproved)
            .toList();
      } else {
        throw Exception('Ошибка загрузки изображений: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading place images: $e');
      return [];
    }
  }

  Future<void> addLike(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse('$_baseUrl/$userId/$imageId/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка при добавлении лайка: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding like: $e');
      rethrow;
    }
  }

  Future<void> addDislike(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse('$_baseUrl/$userId/$imageId/dislike'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка при добавлении дизлайка: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding dislike: $e');
      rethrow;
    }
  }

  Future<void> removeLike(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.delete(
        Uri.parse('$_baseUrl/$userId/$imageId/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка при удалении лайка: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing like: $e');
      rethrow;
    }
  }

  Future<void> removeDislike(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.delete(
        Uri.parse('$_baseUrl/$userId/$imageId/dislike'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка при удалении дизлайка: ${response.statusCode}');
      }
    } catch (e) {
      print('Error removing dislike: $e');
      rethrow;
    }
  }

  Future<PlaceImage> uploadImage(int placeId, String imageUrl) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse('$_baseUrl/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'placeId': placeId,
          'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 200) {
        return PlaceImage.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Ошибка при загрузке изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<PlaceImage> getImageInfo(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_baseUrl/image/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return PlaceImage.fromJson(jsonDecode(response.body));
      } else {
        print('Response body: ${response.body}');
        throw Exception(
            'Ошибка получения информации об изображении: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting image info: $e');
      rethrow;
    }
  }

  Future<Map<String, bool>> getRatingState(int imageId, int userId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_baseUrl/rating/$userId/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'liked': data['liked'] ?? false,
          'disliked': data['disliked'] ?? false,
        };
      } else {
        print('Response body: ${response.body}');
        throw Exception(
            'Ошибка получения состояния оценки: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting rating state: $e');
      return {'liked': false, 'disliked': false};
    }
  }
}
