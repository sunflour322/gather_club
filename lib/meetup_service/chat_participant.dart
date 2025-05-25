class ChatParticipant {
  final int participantId;
  final int chatId;
  final int userId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String role; // 'member', 'admin', 'creator'

  ChatParticipant({
    required this.participantId,
    required this.chatId,
    required this.userId,
    required this.joinedAt,
    this.leftAt,
    required this.role,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      participantId: json['participantId'],
      chatId: json['chatId'],
      userId: json['userId'],
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      role: json['role'] ?? 'member',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'chatId': chatId,
      'userId': userId,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'role': role,
    };
  }
}
