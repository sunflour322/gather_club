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

  factory Chat.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to Chat:');
    print('- type: ${json['type']}');
    print('- meetupStatus: ${json['meetupStatus']}');
    print('- currentUserStatus: ${json['currentUserStatus']}');

    final chat = Chat(
      chatId: json['chatId'],
      name: json['name'],
      participants: (json['participants'] as List?)
              ?.map((p) => ChatParticipant.fromJson(p))
              .toList() ??
          [],
      lastMessageContent: json['lastMessageContent'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      type: json['type'] == 'meetup'
          ? ChatType.meetup
          : json['isGroup'] == true
              ? ChatType.group
              : ChatType.direct,
      meetupId: json['meetupId'],
      isGroup: json['isGroup'] ?? false,
      createdById: json['createdById'],
      createdByName: json['createdByName'],
      createdByAvatar: json['createdByAvatar'],
      createdAt: DateTime.parse(json['createdAt']),
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
