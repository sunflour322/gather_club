class Chat {
  final int chatId;
  final String? name;
  final int? createdBy;
  final DateTime createdAt;
  final bool isGroup;
  final int? themeId;
  final int? meetupId;
  final DateTime? lastMessageAt;

  Chat({
    required this.chatId,
    this.name,
    this.createdBy,
    required this.createdAt,
    required this.isGroup,
    this.themeId,
    this.meetupId,
    this.lastMessageAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chatId'],
      name: json['name'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      isGroup: json['isGroup'] ?? false,
      themeId: json['themeId'],
      meetupId: json['meetupId'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isGroup': isGroup,
      'themeId': themeId,
      'meetupId': meetupId,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
    };
  }
}
