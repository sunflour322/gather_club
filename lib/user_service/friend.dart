class Friend {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String status; // 'pending', 'accepted', 'blocked'
  final bool isOutgoing; // true если запрос отправлен текущим пользователем
  final int? friendshipId;

  Friend({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.status,
    required this.isOutgoing,
    this.friendshipId,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['user2Id'] ?? json['user1Id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
      status: json['status'] ?? 'pending',
      isOutgoing: json['user1Id'] == json['currentUserId'],
      friendshipId: json['friendshipId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'status': status,
      'isOutgoing': isOutgoing,
      'friendshipId': friendshipId,
    };
  }
}
