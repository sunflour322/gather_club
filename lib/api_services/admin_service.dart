import 'dart:convert';
import 'dart:io';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AdminService {
  final AuthProvider _authProvider;
  final String _placesBaseUrl = 'http://212.67.8.92:8080/places';
  final String _placeImagesBaseUrl = 'http://212.67.8.92:8080/place-images';
  final http.Client _client = http.Client();

  AdminService(this._authProvider);

  // Получение всех мест
  Future<List<Place>> getAllPlaces() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse(_placesBaseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Place.fromJson(json)).toList();
      } else {
        throw Exception('Ошибка получения мест: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting places: $e');
      rethrow;
    }
  }

  // Получение места по ID
  Future<Place> getPlaceById(int placeId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_placesBaseUrl/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return Place.fromJson(json.decode(response.body));
      } else {
        throw Exception('Ошибка получения места: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting place: $e');
      rethrow;
    }
  }

  // Создание нового места
  Future<Place> createPlace(Map<String, dynamic> placeData) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse(_placesBaseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(placeData),
      );

      if (response.statusCode == 201) {
        return Place.fromJson(json.decode(response.body));
      } else {
        throw Exception('Ошибка создания места: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating place: $e');
      rethrow;
    }
  }

  // Обновление места
  Future<Place> updatePlace(int placeId, Map<String, dynamic> placeData) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.put(
        Uri.parse('$_placesBaseUrl/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(placeData),
      );

      if (response.statusCode == 200) {
        return Place.fromJson(json.decode(response.body));
      } else {
        throw Exception('Ошибка обновления места: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating place: $e');
      rethrow;
    }
  }

  // Загрузка изображения для места
  Future<Place> updatePlaceImage(int placeId, File imageFile) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_placesBaseUrl/$placeId/image'),
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
        return Place.fromJson(json.decode(response.body));
      } else {
        print('Response body: ${response.body}');
        throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  // Удаление места
  Future<void> deletePlace(int placeId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.delete(
        Uri.parse('$_placesBaseUrl/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Ошибка удаления места: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting place: $e');
      rethrow;
    }
  }

  // Получение ожидающих модерации изображений
  Future<List<PlaceImage>> getPendingImages() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.get(
        Uri.parse('$_placeImagesBaseUrl/admin/pending'),
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
      print('Error getting pending images: $e');
      rethrow;
    }
  }

  // Одобрение изображения
  Future<void> approveImage(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.put(
        Uri.parse('$_placeImagesBaseUrl/admin/approve/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка одобрения изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error approving image: $e');
      rethrow;
    }
  }

  // Отклонение изображения
  Future<void> rejectImage(int imageId) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.delete(
        Uri.parse('$_placeImagesBaseUrl/admin/reject/$imageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Ошибка отклонения изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error rejecting image: $e');
      rethrow;
    }
  }

  // Модерация изображения (одобрение или отклонение)
  Future<void> moderateImage(int imageId, bool approve) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      final response = await _client.post(
        Uri.parse(
            '$_placeImagesBaseUrl/admin/moderate/$imageId?approve=$approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка модерации изображения: ${response.statusCode}');
      }
    } catch (e) {
      print('Error moderating image: $e');
      rethrow;
    }
  }
}
