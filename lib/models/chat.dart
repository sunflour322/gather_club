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
    print('Converting JSON to Chat:');
    print('- type: ${json['type']}');
    print('- meetupStatus: ${json['meetupStatus']}');
    print('- currentUserStatus: ${json['currentUserStatus']}');

    // Определяем тип чата
    ChatType? chatType;

    // Если явно указан тип
    if (json['type'] != null) {
      switch (json['type'].toString().toLowerCase()) {
        case 'meetup':
          chatType = ChatType.meetup;
          break;
        case 'direct':
          chatType = ChatType.direct;
          break;
        case 'group':
          chatType = ChatType.group;
          break;
      }
    }

    // Если тип не определён, но есть meetupId
    if (chatType == null && json['meetupId'] != null) {
      chatType = ChatType.meetup;
    }

    // Если тип всё ещё не определён
    if (chatType == null) {
      chatType = json['isGroup'] == true ? ChatType.group : ChatType.direct;
    }

    // Проверяем обязательные поля
    if (json['chatId'] == null) {
      throw Exception('Chat ID is required');
    }

    final chat = Chat(
      chatId: json['chatId'],
      name: json['name'] ?? 'Без названия',
      participants: (json['participants'] as List?)
              ?.map((p) => ChatParticipant.fromJson(p))
              .toList() ??
          [],
      lastMessageContent: json['lastMessageContent'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      type: chatType,
      meetupId: json['meetupId'],
      isGroup: chatType == ChatType.group,
      createdById: json['createdById'] ?? 0,
      createdByName: json['createdByName'] ?? 'Unknown',
      createdByAvatar: json['createdByAvatar'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'])
          : null,
      meetupStatus: _parseMeetupStatus(json['meetupStatus']),
      currentUserStatus: _parseParticipantStatus(json['currentUserStatus']),
    );

    print('Converted Chat:');
    print('- type: ${chat.type}');
    print('- meetupStatus: ${chat.meetupStatus}');
    print('- currentUserStatus: ${chat.currentUserStatus}');
    print('- isActive: ${chat.isActive}');

    return chat;
  }

  static MeetupStatus? _parseMeetupStatus(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'planned':
        return MeetupStatus.planned;
      case 'completed':
        return MeetupStatus.completed;
      case 'cancelled':
        return MeetupStatus.cancelled;
      default:
        return null;
    }
  }

  static ParticipantStatus? _parseParticipantStatus(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'invited':
        return ParticipantStatus.invited;
      case 'accepted':
        return ParticipantStatus.accepted;
      case 'declined':
        return ParticipantStatus.declined;
      default:
        return null;
    }
  }

  bool get isActive {
    return type == ChatType.meetup &&
        meetupStatus == MeetupStatus.planned &&
        currentUserStatus == ParticipantStatus.accepted;
  }

  bool get isCompleted {
    return type == ChatType.meetup &&
        (meetupStatus == MeetupStatus.completed ||
            meetupStatus == MeetupStatus.cancelled ||
            (scheduledTime != null && DateTime.now().isAfter(scheduledTime!)));
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
    return ChatParticipant(
      userId: json['userId'],
      name: json['userName'] ?? json['name'],
      avatarUrl: json['userAvatar'] ?? json['avatarUrl'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
    );
  }
}
