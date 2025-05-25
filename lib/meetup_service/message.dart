class Message {
  final int messageId;
  final int chatId;
  final int senderId;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isSystem;
  final int? replyTo;

  Message({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.readAt,
    required this.isSystem,
    this.replyTo,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['messageId'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      content: json['content'],
      sentAt: DateTime.parse(json['sentAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isSystem: json['isSystem'] ?? false,
      replyTo: json['replyTo'],
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
      'replyTo': replyTo,
    };
  }
}
