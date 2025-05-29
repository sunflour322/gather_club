import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'dart:io';

class UserService {
  final AuthProvider _authProvider;
  final String baseUrl = 'http://212.67.8.92:8080/users';

  UserService(this._authProvider);

  Future<String> updateAvatar(File imageFile) async {
    try {
      final token = await _authProvider.getToken();
      final userId = await _authProvider.getUserId();
      if (token == null) throw Exception('Не авторизован');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/$userId/avatar'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      });

      final mimeType = imageFile.path.split('.').last.toLowerCase();
      final contentType = MediaType('image', mimeType);

      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: contentType,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['avatarUrl'];
      } else {
        print('Response body: ${response.body}');
        throw Exception('Ошибка загрузки аватара: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
    }
  }
}
