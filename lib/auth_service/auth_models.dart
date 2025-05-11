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

  AuthResponse({required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
    );
  }
}
