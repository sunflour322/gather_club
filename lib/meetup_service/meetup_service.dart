import 'dart:convert';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/models/api_response.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class MeetupService {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080/meetups';

  MeetupService(this._authProvider);

  Future<Map<String, dynamic>> createMeetup(
      int userId, Map<String, dynamic> meetupRequest) async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      developer.log('Creating meetup with token: $token');
      developer.log('Request URL: $_baseUrl');
      developer.log('Request body: ${jsonEncode(meetupRequest)}');

      final response = await http.post(
        Uri.parse('$_baseUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'creatorId': userId,
          ...meetupRequest,
        }),
      );

      developer.log('Received response with status: ${response.statusCode}');
      developer.log('Response headers: ${response.headers}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.isEmpty) {
          developer.log('Empty response body, returning success status');
          return {'status': 'success'};
        }

        try {
          final responseData = jsonDecode(response.body);
          developer.log('Parsed response data: $responseData');
          if (responseData['place'] != null) {
            developer.log('Place data in response: ${responseData['place']}');
          }
          return responseData;
        } catch (e) {
          developer.log('Error parsing response JSON: $e');
          return {'status': 'success', 'error': 'Could not parse response'};
        }
      }

      throw Exception(
          'Ошибка при создании встречи: ${response.statusCode} - ${response.body}');
    } catch (e, stackTrace) {
      developer.log(
        'Error in createMeetup',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMeetup(int meetupId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$meetupId'),
      headers: await _getHeaders(),
    );

    final apiResponse = ApiResponse.fromJson(response);
    return apiResponse.data;
  }

  Future<List<Map<String, dynamic>>> getUserMeetups(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/$userId'),
      headers: await _getHeaders(),
    );

    final apiResponse = ApiResponse.fromJson(response);
    return List<Map<String, dynamic>>.from(apiResponse.data);
  }

  Future<void> inviteParticipants(int meetupId, List<int> userIds) async {
    await http.post(
      Uri.parse('$_baseUrl/$meetupId/invite'),
      headers: await _getHeaders(),
      body: jsonEncode(userIds),
    );
  }

  Future<Map<String, dynamic>> updateParticipantStatus(
    int meetupId,
    int userId,
    String status,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$meetupId/participants/$userId?status=$status'),
      headers: await _getHeaders(),
    );

    final apiResponse = ApiResponse.fromJson(response);
    return apiResponse.data;
  }

  Future<List<Map<String, dynamic>>> getInvitedMeetups(int userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/invitations/$userId'),
      headers: await _getHeaders(),
    );

    final apiResponse = ApiResponse.fromJson(response);
    return List<Map<String, dynamic>>.from(apiResponse.data);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authProvider.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
