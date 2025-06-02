import 'package:flutter/material.dart';

enum ChatType { meetup, direct, group }

enum MeetupStatus { planned, completed, cancelled }

enum ParticipantStatus { invited, accepted, declined }

class Chat {
  final int chatId;
  final String name;
  final List<ChatParticipant> participants;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final ChatType type;
  final int? meetupId;
  final bool isGroup;
  final int createdById;
  final String createdByName;
  final String? createdByAvatar;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final MeetupStatus? meetupStatus;
  final ParticipantStatus? currentUserStatus;

  Chat({
    required this.chatId,
    required this.name,
    required this.participants,
    this.lastMessageContent,
    this.lastMessageAt,
    required this.type,
    this.meetupId,
    required this.isGroup,
    required this.createdById,
    required this.createdByName,
    this.createdByAvatar,
    required this.createdAt,
    this.scheduledTime,
    this.meetupStatus,
    this.currentUserStatus,
  });

  Chat copyWith({
    int? chatId,
    String? name,
    List<ChatParticipant>? participants,
    String? lastMessageContent,
    DateTime? lastMessageAt,
    ChatType? type,
    int? meetupId,
    bool? isGroup,
    int? createdById,
    String? createdByName,
    String? createdByAvatar,
    DateTime? createdAt,
    DateTime? scheduledTime,
    MeetupStatus? meetupStatus,
    ParticipantStatus? currentUserStatus,
  }) {
    return Chat(
      chatId: chatId ?? this.chatId,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      type: type ?? this.type,
      meetupId: meetupId ?? this.meetupId,
      isGroup: isGroup ?? this.isGroup,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdByAvatar: createdByAvatar ?? this.createdByAvatar,
      createdAt: createdAt ?? this.createdAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      meetupStatus: meetupStatus ?? this.meetupStatus,
      currentUserStatus: currentUserStatus ?? this.currentUserStatus,
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Проверяем обязательные поля
    final chatId = json['chatId'] ?? json['meetupId'];
    if (chatId == null) {
      throw Exception('Chat ID is required');
    }

    // Парсим информацию о создателе
    int createdById = 0;
    String createdByName = 'Unknown';
    String? createdByAvatar;

    if (json['creator'] != null) {
      // Для приглашений
      final creator = json['creator'] as Map<String, dynamic>;
      createdById = creator['userId'] ?? 0;
      createdByName = creator['username'] ?? 'Unknown';
      createdByAvatar = creator['avatarUrl'];
      print('Parsed creator from invitation: $createdByName');
    } else if (json['createdBy'] != null) {
      // Для активных встреч
      if (json['createdBy'] is Map) {
        final createdBy = json['createdBy'] as Map<String, dynamic>;
        createdById = createdBy['userId'] ?? 0;
        createdByName = createdBy['username'] ?? 'Unknown';
        createdByAvatar = createdBy['avatarUrl'];
      } else {
        createdById = json['createdBy'] as int;
      }
    } else if (json['createdById'] != null) {
      createdById = json['createdById'] as int;
      createdByName = json['createdByName'] ?? 'Unknown';
      createdByAvatar = json['createdByAvatar'];
    }

    // Определяем тип чата
    final chatType = ChatType.meetup;

    // Парсим участников
    List<ChatParticipant> participants = [];
    try {
      if (json['participants'] != null) {
        // Для приглашений и архивных встреч
        participants = (json['participants'] as List).map((p) {
          // Проверяем структуру участника
          if (p['user'] != null) {
            // Формат для приглашений и архивных встреч
            final user = p['user'] as Map<String, dynamic>;
            return ChatParticipant.fromJson({
              'userId': user['userId'],
              'name': user['username'],
              'avatarUrl': user['avatarUrl'],
              'role': p['status'] ?? 'participant',
              'joinedAt':
                  p['invitedAt'] ?? p['respondedAt'] ?? json['createdAt'],
            });
          } else {
            // Стандартный формат
            return ChatParticipant.fromJson(p);
          }
        }).toList();
        print(
            'Parsed ${participants.length} participants from invitation/archive');
      } else if (json['meetup'] != null &&
          json['meetup']['participants'] != null) {
        // Пробуем получить участников из данных встречи
        participants = (json['meetup']['participants'] as List)
            .map((p) => ChatParticipant.fromJson({
                  'userId': p['userId'] ?? p['user']?['userId'],
                  'name': p['username'] ?? p['user']?['username'] ?? 'Unknown',
                  'avatarUrl': p['avatarUrl'] ?? p['user']?['avatarUrl'],
                  'role': 'participant',
                  'joinedAt': p['joinedAt'] ?? json['createdAt'],
                }))
            .toList();
      }
    } catch (e) {
      print('Warning: Failed to parse participants: $e');
    }

    // Парсим даты
    DateTime? lastMessageAt;
    DateTime? scheduledTime;
    DateTime createdAt;

    try {
      // Пробуем получить время последнего сообщения
      lastMessageAt = json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null;

      // Пробуем получить время встречи из разных источников
      print('Parsing scheduledTime from JSON:');
      print('meetup: ${json['meetup']}');
      print('scheduledTime in meetup: ${json['meetup']?['scheduledTime']}');
      print('direct scheduledTime: ${json['scheduledTime']}');
      print('meetupScheduledTime: ${json['meetupScheduledTime']}');

      if (json['scheduledTime'] != null) {
        // Для приглашений
        scheduledTime = DateTime.parse(json['scheduledTime']);
        print('Parsed scheduledTime from invitation: $scheduledTime');
      } else if (json['meetupScheduledTime'] != null) {
        scheduledTime = DateTime.parse(json['meetupScheduledTime']);
        print('Parsed scheduledTime from meetupScheduledTime: $scheduledTime');
      } else if (json['meetup'] != null &&
          json['meetup']['scheduledTime'] != null) {
        scheduledTime = DateTime.parse(json['meetup']['scheduledTime']);
        print('Parsed scheduledTime from meetup: $scheduledTime');
      } else {
        scheduledTime = null;
        print('No scheduledTime found in JSON');
      }

      // Получаем время создания
      if (json['createdAt'] != null) {
        // Для приглашений
        createdAt = DateTime.parse(json['createdAt']);
      } else if (json['meetup'] != null &&
          json['meetup']['createdAt'] != null) {
        createdAt = DateTime.parse(json['meetup']['createdAt']);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      print('Warning: Failed to parse dates: $e');
      createdAt = DateTime.now();
    }

    // Парсим информацию о последнем сообщении
    String? lastMessageContent;
    try {
      if (json['lastMessage'] != null && json['lastMessage'] is Map) {
        lastMessageContent = json['lastMessage']['content'];
      } else {
        lastMessageContent = json['lastMessageContent'];
      }
    } catch (e) {
      print('Warning: Failed to parse last message: $e');
    }

    // Парсим статусы
    final meetupStatus =
        _parseMeetupStatus(json['status'] ?? json['meetup']?['status']);

    // Проверяем наличие participant_status в ответе
    String? participantStatusStr;
    if (json['participants'] != null && json['participants'].isNotEmpty) {
      // Для приглашений
      participantStatusStr = json['participants'][0]['status'];
    } else {
      participantStatusStr = json['participant_status'] ??
          json['participantStatus'] ??
          json['meetup']?['participantStatus'];
    }
    final currentUserStatus = _parseParticipantStatus(participantStatusStr);

    return Chat(
      chatId: chatId,
      name: json['name'] ?? json['meetup']?['name'] ?? 'Без названия',
      participants: participants,
      lastMessageContent: lastMessageContent,
      lastMessageAt: lastMessageAt,
      type: chatType,
      meetupId: json['meetupId'] ?? json['meetup']?['meetupId'],
      isGroup: true,
      createdById: createdById,
      createdByName: createdByName,
      createdByAvatar: createdByAvatar,
      createdAt: createdAt,
      scheduledTime: scheduledTime,
      meetupStatus: meetupStatus,
      currentUserStatus: currentUserStatus,
    );
  }

  static MeetupStatus? _parseMeetupStatus(String? status) {
    if (status == null) return null;

    print('Parsing meetup status: $status');
    switch (status.toLowerCase()) {
      case 'planned':
        return MeetupStatus.planned;
      case 'completed':
        return MeetupStatus.completed;
      case 'cancelled':
        return MeetupStatus.cancelled;
      default:
        print('Unknown meetup status: $status');
        return null;
    }
  }

  static ParticipantStatus? _parseParticipantStatus(String? status) {
    if (status == null) return null;

    print('Parsing participant status: $status');
    switch (status.toLowerCase()) {
      case 'invited':
        return ParticipantStatus.invited;
      case 'accepted':
      case 'attended':
      case 'active':
        return ParticipantStatus.accepted;
      case 'declined':
      case 'rejected':
        return ParticipantStatus.declined;
      default:
        print('Unknown participant status: $status');
        return null;
    }
  }
}

class ChatParticipant {
  final int userId;
  final String name;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final DateTime? leftAt;

  ChatParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.leftAt,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    // Проверяем наличие обязательных полей
    final userId = json['userId'];
    if (userId == null) {
      throw Exception('userId is required for ChatParticipant');
    }

    final name = json['userName'] ?? json['name'] ?? json['username'];
    if (name == null) {
      throw Exception('name is required for ChatParticipant');
    }

    final role = json['role'] ?? 'participant';

    final joinedAtStr = json['joinedAt'];
    if (joinedAtStr == null) {
      throw Exception('joinedAt is required for ChatParticipant');
    }

    return ChatParticipant(
      userId: userId,
      name: name,
      avatarUrl: json['userAvatar'] ?? json['avatarUrl'],
      role: role,
      joinedAt: DateTime.parse(joinedAtStr),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
    );
  }
}
