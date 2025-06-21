import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service/auth_provider.dart';

// Модели для ответов от API
class ProfileFrameResponse {
  final int? id;
  final String? name;
  final String? previewUrl;
  final String? frameUrl;

  ProfileFrameResponse({
    this.id,
    this.name,
    this.previewUrl,
    this.frameUrl,
  });

  factory ProfileFrameResponse.fromJson(Map<String, dynamic> json) {
    return ProfileFrameResponse(
      id: json['id'],
      name: json['name'],
      previewUrl: json['previewUrl'],
      frameUrl: json['frameUrl'],
    );
  }

  @override
  String toString() {
    return 'ProfileFrameResponse(id: $id, name: $name, previewUrl: $previewUrl, frameUrl: $frameUrl)';
  }
}

class ProfileBackgroundResponse {
  final int? id;
  final String? name;
  final String? previewUrl;
  final String? backgroundUrl;

  ProfileBackgroundResponse({
    this.id,
    this.name,
    this.previewUrl,
    this.backgroundUrl,
  });

  factory ProfileBackgroundResponse.fromJson(Map<String, dynamic> json) {
    return ProfileBackgroundResponse(
      id: json['id'],
      name: json['name'],
      previewUrl: json['previewUrl'],
      backgroundUrl: json['backgroundUrl'],
    );
  }

  @override
  String toString() {
    return 'ProfileBackgroundResponse(id: $id, name: $name, previewUrl: $previewUrl, backgroundUrl: $backgroundUrl)';
  }
}

class ChatThemeResponse {
  final int? id;
  final String? name;
  final String? previewUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? backgroundColor;

  ChatThemeResponse({
    this.id,
    this.name,
    this.previewUrl,
    this.primaryColor,
    this.secondaryColor,
    this.backgroundColor,
  });

  factory ChatThemeResponse.fromJson(Map<String, dynamic> json) {
    return ChatThemeResponse(
      id: json['id'],
      name: json['name'],
      previewUrl: json['previewUrl'],
      primaryColor: json['primaryColor'],
      secondaryColor: json['secondaryColor'],
      backgroundColor: json['backgroundColor'],
    );
  }

  @override
  String toString() {
    return 'ChatThemeResponse(id: $id, name: $name, previewUrl: $previewUrl, primaryColor: $primaryColor, secondaryColor: $secondaryColor, backgroundColor: $backgroundColor)';
  }
}

class CustomizationService {
  static const String baseUrl = 'http://212.67.8.92:8080';
  final AuthProvider _authProvider;

  CustomizationService(this._authProvider);

  // Получение активной рамки профиля пользователя
  Future<ProfileFrameResponse?> getActiveProfileFrame(int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customization/active/frame/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'Ответ от API /customization/active/frame/$userId: ${response.statusCode}');
      print('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Декодированные данные рамки: $data');

        // Проверяем, есть ли в ответе поле data
        final responseData =
            data is Map && data.containsKey('data') ? data['data'] : data;
        print('Данные для создания ProfileFrameResponse: $responseData');

        if (responseData is Map<String, dynamic>) {
          return ProfileFrameResponse.fromJson(responseData);
        } else {
          print(
              'Ошибка: responseData не является Map<String, dynamic>: $responseData');
          return null;
        }
      } else {
        print('Ошибка загрузки активной рамки профиля: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Ошибка при получении активной рамки профиля: $e');
      return null;
    }
  }

  // Получение активного фона профиля пользователя
  Future<ProfileBackgroundResponse?> getActiveProfileBackground(
      int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customization/active/background/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'Ответ от API /customization/active/background/$userId: ${response.statusCode}');
      print('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Декодированные данные фона: $data');

        // Проверяем, есть ли в ответе поле data
        final responseData =
            data is Map && data.containsKey('data') ? data['data'] : data;
        print('Данные для создания ProfileBackgroundResponse: $responseData');

        if (responseData is Map<String, dynamic>) {
          return ProfileBackgroundResponse.fromJson(responseData);
        } else {
          print(
              'Ошибка: responseData не является Map<String, dynamic>: $responseData');
          return null;
        }
      } else {
        print('Ошибка загрузки активного фона профиля: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Ошибка при получении активного фона профиля: $e');
      return null;
    }
  }

  // Получение активной темы чата пользователя
  Future<ChatThemeResponse?> getActiveChatTheme(int userId) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Не авторизован');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customization/active/chat-theme/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          'Ответ от API /customization/active/chat-theme/$userId: ${response.statusCode}');
      print('Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Декодированные данные темы чата: $data');

        // Проверяем, есть ли в ответе поле data
        final responseData =
            data is Map && data.containsKey('data') ? data['data'] : data;
        print('Данные для создания ChatThemeResponse: $responseData');

        if (responseData is Map<String, dynamic>) {
          return ChatThemeResponse.fromJson(responseData);
        } else {
          print(
              'Ошибка: responseData не является Map<String, dynamic>: $responseData');
          return null;
        }
      } else {
        print('Ошибка загрузки активной темы чата: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Ошибка при получении активной темы чата: $e');
      return null;
    }
  }

  // Вспомогательный метод для получения URL превью активной рамки профиля
  Future<String?> getActiveProfileFrameUrl(int userId) async {
    try {
      final frameResponse = await getActiveProfileFrame(userId);
      print('Получен ответ для рамки профиля: $frameResponse');
      final url = frameResponse?.previewUrl;
      print('URL рамки профиля: $url');
      return url;
    } catch (e) {
      print('Ошибка при получении URL активной рамки профиля: $e');
      return null;
    }
  }

  // Вспомогательный метод для получения URL превью активного фона профиля
  Future<String?> getActiveProfileBackgroundUrl(int userId) async {
    try {
      final backgroundResponse = await getActiveProfileBackground(userId);
      print('Получен ответ для фона профиля: $backgroundResponse');
      final url = backgroundResponse?.previewUrl;
      print('URL фона профиля: $url');
      return url;
    } catch (e) {
      print('Ошибка при получении URL активного фона профиля: $e');
      return null;
    }
  }

  // Вспомогательный метод для получения URL превью активной темы чата
  Future<String?> getActiveChatThemeUrl(int userId) async {
    try {
      final themeResponse = await getActiveChatTheme(userId);
      print('Получен ответ для темы чата: $themeResponse');
      final url = themeResponse?.previewUrl;
      print('URL темы чата: $url');
      return url;
    } catch (e) {
      print('Ошибка при получении URL активной темы чата: $e');
      return null;
    }
  }
}
