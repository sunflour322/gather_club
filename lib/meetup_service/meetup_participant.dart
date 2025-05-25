class MeetupParticipant {
  final int participantId;
  final int meetupId;
  final int userId;
  final String status; // 'invited', 'accepted', 'declined', 'attended'
  final DateTime invitedAt;
  final DateTime? respondedAt;

  MeetupParticipant({
    required this.participantId,
    required this.meetupId,
    required this.userId,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
  });

  factory MeetupParticipant.fromJson(Map<String, dynamic> json) {
    return MeetupParticipant(
      participantId: json['participantId'],
      meetupId: json['meetupId'],
      userId: json['userId'],
      status: json['status'] ?? 'invited',
      invitedAt: DateTime.parse(json['invitedAt']),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'meetupId': meetupId,
      'userId': userId,
      'status': status,
      'invitedAt': invitedAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }
}
