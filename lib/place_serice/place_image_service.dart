import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/place_serice/place.dart';
import 'dart:io';

class PlaceImageService {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080/place-images';
  final http.Client _client = http.Client();

  PlaceImageService(this._authProvider);

  Future<String> uploadImage(int placeId, File imageFile) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/place/$placeId'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      });

      final mimeType = imageFile.path.split('.').last.toLowerCase();
      final contentType = MediaType('image', mimeType);

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: contentType,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['imageUrl'];
      } else {
        print('Response body: ${response.body}');
        throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

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
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PlaceImage.fromJson(json)).toList();
      } else {
        throw Exception('Ошибка получения изображений: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting place images: $e');
      rethrow;
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
