import 'chat_participant_info.dart';

class UserResponse {
  final int userId;
  final String username;
  final String? avatarUrl;
  final bool? isOnline;

  UserResponse({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.isOnline,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userId: json['userId'],
      username: json['username'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'],
    );
  }
}

class MeetupParticipantResponse {
  final int participantId;
  final int meetupId;
  final UserResponse user;
  final String status;
  final DateTime? invitedAt;
  final DateTime? respondedAt;

  MeetupParticipantResponse({
    required this.participantId,
    required this.meetupId,
    required this.user,
    required this.status,
    this.invitedAt,
    this.respondedAt,
  });

  factory MeetupParticipantResponse.fromJson(Map<String, dynamic> json) {
    return MeetupParticipantResponse(
      participantId: json['participantId'],
      meetupId: json['meetupId'],
      user: UserResponse.fromJson(json['user']),
      status: json['status'],
      invitedAt:
          json['invitedAt'] != null ? DateTime.parse(json['invitedAt']) : null,
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  // Преобразование в ChatParticipantInfo для использования в ParticipantsDialog
  ChatParticipantInfo toChatParticipantInfo() {
    return ChatParticipantInfo(
      userId: user.userId,
      username: user.username,
      avatarUrl: user.avatarUrl,
      role: _mapStatusToRole(status),
      joinedAt: invitedAt ?? DateTime.now(),
      isOnline: user.isOnline,
    );
  }

  // Преобразование статуса участника в роль для отображения
  String _mapStatusToRole(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'participant'; // Принявший участие
      case 'invited':
        return 'moderator'; // Приглашенный (ожидающий)
      case 'declined':
        return 'guest'; // Отклонивший
      default:
        return 'participant';
    }
  }
}
