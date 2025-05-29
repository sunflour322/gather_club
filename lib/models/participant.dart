class Participant {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String status;
  final DateTime? invitedAt;
  final DateTime? respondedAt;

  Participant({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.status,
    this.invitedAt,
    this.respondedAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      userId: json['userId'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      status: json['status'],
      invitedAt:
          json['invitedAt'] != null ? DateTime.parse(json['invitedAt']) : null,
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'status': status,
      'invitedAt': invitedAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }
}
