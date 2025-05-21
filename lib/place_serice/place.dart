class Place {
  final int placeId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? category;
  final String? workingHours;
  final String? phone;
  final List<String>? userImages; // Фотографии от пользователей

  Place({
    required this.placeId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.category,
    this.workingHours,
    this.phone,
    this.userImages,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      placeId: json['placeId'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      imageUrl: json['imageUrl'],
      category: json['category'],
      workingHours: json['workingHours'],
      phone: json['phone'],
      userImages: json['userImages'] != null
          ? List<String>.from(json['userImages'])
          : null,
    );
  }
}
