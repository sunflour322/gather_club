import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:gather_club/api_services/auth_service/auth_provider.dart';
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
        Uri.parse('$baseUrl/current/avatar'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      });

      final mimeType = lookupMimeType(imageFile.path);
      final contentType = mimeType != null
          ? MediaType.parse(mimeType)
          : MediaType('image', 'jpeg');

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
