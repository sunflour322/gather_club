class ChatParticipant {
  final int participantId;
  final int chatId;
  final int userId;
  final String userName;
  final String? userAvatar;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String role;

  ChatParticipant({
    required this.participantId,
    required this.chatId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.joinedAt,
    this.leftAt,
    required this.role,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      participantId: json['participantId'],
      chatId: json['chatId'],
      userId: json['userId'],
      userName: json['userName'],
      userAvatar: json['userAvatar'],
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'chatId': chatId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'role': role,
    };
  }

  bool get isActive => leftAt == null;
}
