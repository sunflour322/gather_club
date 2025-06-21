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
    print('Creating Friend from JSON: $json');

    final currentUserId = json['currentUserId'];
    final user1Id = json['user1Id'];
    final user2Id = json['user2Id'];

    // Определяем ID пользователя (не текущего)
    final userId = currentUserId == user1Id ? user2Id : user1Id;

    // Определяем, является ли запрос исходящим
    final isOutgoing = currentUserId == user1Id;

    final friend = Friend(
      userId: userId ?? json['userId'],
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
      status: json['status']?.toLowerCase() ?? 'pending',
      isOutgoing: isOutgoing,
      friendshipId: json['friendshipId'] ?? json['id'],
    );

    print('Created Friend object: $friend');
    return friend;
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

  @override
  String toString() {
    return 'Friend{userId: $userId, username: $username, status: $status, isOutgoing: $isOutgoing, friendshipId: $friendshipId}';
  }
}
