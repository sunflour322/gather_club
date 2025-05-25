import 'dart:convert';

class RegisterRequest {
  final String username;
  final String email;
  final String passwordHash;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
      };
}

class LoginRequest {
  final String usernameOrEmail;
  final String passwordHash;

  LoginRequest({
    required this.usernameOrEmail,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
        'usernameOrEmail': usernameOrEmail,
        'passwordHash': passwordHash,
      };
}

class AuthResponse {
  final String token;
  final int userId;

  AuthResponse({required this.token, required this.userId});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    final userIdStr = token.split('.')[1];
    final decodedPayload =
        utf8.decode(base64Url.decode(base64Url.normalize(userIdStr)));
    final payload = jsonDecode(decodedPayload);
    final userId = int.parse(payload['sub']);

    return AuthResponse(
      token: token,
      userId: userId,
    );
  }
}
