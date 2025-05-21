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
  final List<PlaceImage>? userImages; // Теперь отдельный класс для изображений

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
          ? (json['userImages'] as List)
              .map((i) => PlaceImage.fromJson(i))
              .toList()
          : null,
    );
  }
}

class PlaceImage {
  final int imageId;
  final String imageUrl;
  final int? uploadedBy;
  final DateTime uploadedAt;
  final bool isApproved;
  final int likes;
  final int dislikes;

  PlaceImage({
    required this.imageId,
    required this.imageUrl,
    this.uploadedBy,
    required this.uploadedAt,
    required this.isApproved,
    required this.likes,
    required this.dislikes,
  });

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(
      imageId: json['imageId'],
      imageUrl: json['imageUrl'],
      uploadedBy: json['uploadedBy'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      isApproved: json['isApproved'],
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
    );
  }
}

class Reward {
  final int amount;
  final String currency;

  Reward({required this.amount, required this.currency});
}
