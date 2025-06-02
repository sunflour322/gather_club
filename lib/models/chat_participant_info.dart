import 'package:flutter/foundation.dart';

class ChatParticipantInfo {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;

  ChatParticipantInfo({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory ChatParticipantInfo.fromJson(Map<String, dynamic> json) {
    // Проверяем, содержит ли объект вложенный объект user (формат для приглашений)
    if (json['user'] != null) {
      final user = json['user'] as Map<String, dynamic>;
      return ChatParticipantInfo(
        userId: user['userId'],
        username: user['username'],
        avatarUrl: user['avatarUrl'],
        role: json['status'] ?? 'participant',
        joinedAt: DateTime.parse(
            json['invitedAt'] ?? DateTime.now().toIso8601String()),
      );
    }

    // Стандартный формат
    return ChatParticipantInfo(
      userId: json['userId'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'participant',
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParticipantInfo &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
