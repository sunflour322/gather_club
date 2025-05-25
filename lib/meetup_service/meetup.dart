class Meetup {
  final int meetupId;
  final int? placeId;
  final int creatorId;
  final String name;
  final String? description;
  final DateTime? scheduledTime;
  final DateTime createdAt;
  final String status; // 'planned', 'ongoing', 'completed', 'cancelled'

  Meetup({
    required this.meetupId,
    this.placeId,
    required this.creatorId,
    required this.name,
    this.description,
    this.scheduledTime,
    required this.createdAt,
    required this.status,
  });

  factory Meetup.fromJson(Map<String, dynamic> json) {
    return Meetup(
      meetupId: json['meetupId'],
      placeId: json['placeId'],
      creatorId: json['creatorId'],
      name: json['name'],
      description: json['description'],
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      status: json['status'] ?? 'planned',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meetupId': meetupId,
      'placeId': placeId,
      'creatorId': creatorId,
      'name': name,
      'description': description,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
