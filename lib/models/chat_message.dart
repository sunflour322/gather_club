class ChatMessage {
  final int messageId;
  final int chatId;
  final int senderId;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isSystem;
  final int? replyToId;
  final String senderName;
  final String? senderAvatar;

  ChatMessage({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.readAt,
    required this.isSystem,
    this.replyToId,
    required this.senderName,
    this.senderAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      content: json['content'],
      sentAt: DateTime.parse(json['sentAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isSystem: json['isSystem'] ?? false,
      replyToId: json['replyToId'],
      senderName: json['senderName'],
      senderAvatar: json['senderAvatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isSystem': isSystem,
      'replyToId': replyToId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
    };
  }
}
