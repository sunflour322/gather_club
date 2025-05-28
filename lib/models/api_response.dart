import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final dynamic data;
  final String? message;
  final bool success;

  ApiResponse({
    required this.data,
    this.message,
    required this.success,
  });

  factory ApiResponse.fromJson(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return ApiResponse(
        data: json,
        success: true,
      );
    } else {
      final Map<String, dynamic> json = jsonDecode(response.body);
      throw ApiException(
        message: json['message'] ?? 'Неизвестная ошибка',
        statusCode: response.statusCode,
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException({
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}
