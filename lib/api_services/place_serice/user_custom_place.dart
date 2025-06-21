class UserCustomPlace {
  final int placeId;
  final int userId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? createdAt;
  final int? categoryId;
  final String? imageUrl;

  UserCustomPlace({
    required this.placeId,
    required this.userId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.createdAt,
    this.categoryId,
    this.imageUrl,
  });

  factory UserCustomPlace.fromJson(Map<String, dynamic> json) {
    return UserCustomPlace(
      placeId: json['placeId'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      createdAt: json['createdAt'],
      categoryId: json['categoryId'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'userId': userId,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
    };
  }
}
