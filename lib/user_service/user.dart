class User {
  final int userId;
  final String username;
  final String email;
  final String? passwordHash;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final bool? isVerified;
  final String? verificationToken;
  final String? resetToken;
  final DateTime? resetTokenExpires;
  final String? role;

  User(
      {required this.userId,
      required this.username,
      required this.email,
      this.passwordHash,
      this.phoneNumber,
      this.avatarUrl,
      this.bio,
      this.createdAt,
      this.lastActive,
      this.isVerified,
      this.verificationToken,
      this.resetToken,
      this.resetTokenExpires,
      this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'],
      username: json['username'],
      email: json['email'],
      passwordHash: json['passwordHash'],
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      createdAt: json['createdAt'],
      lastActive: json['lastActive'],
      isVerified: json['isVerified'],
      verificationToken: json['verificationToken'],
      resetToken: json['resetToken'],
      resetTokenExpires: json['resetTokenExpires'],
      role: json['role'],
    );
  }
}
