class Place {
  final int placeId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? category;
  final int? categoryId;
  final String? workingHours;
  final String? phone;
  final String? address;
  final List<PlaceImage>? userImages; // Теперь отдельный класс для изображений

  Place({
    required this.placeId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.category,
    this.categoryId,
    this.workingHours,
    this.phone,
    this.address,
    this.userImages,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // Обработка категории
    String? categoryName;
    int? categoryId;

    if (json['category'] != null && json['category'] is Map<String, dynamic>) {
      // Если категория - это объект с полями
      final categoryObj = json['category'] as Map<String, dynamic>;
      categoryName = categoryObj['name'];
      categoryId = categoryObj['categoryId'];
    } else {
      // Если категория - это строка
      categoryName = json['category'];
    }

    // Если categoryId передан напрямую
    if (json['categoryId'] != null) {
      categoryId = json['categoryId'];
    }

    return Place(
      placeId: json['placeId'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      imageUrl: json['imageUrl'],
      category: categoryName,
      categoryId: categoryId,
      workingHours: json['workingHours'],
      phone: json['phone'],
      address: json['address'],
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
  final int placeId;
  final String imageUrl;
  final int uploadedById;
  final String uploaderUsername;
  final DateTime uploadedAt;
  final bool isApproved;
  int likes;
  int dislikes;

  PlaceImage({
    required this.imageId,
    required this.placeId,
    required this.imageUrl,
    required this.uploadedById,
    required this.uploaderUsername,
    required this.uploadedAt,
    required this.isApproved,
    required this.likes,
    required this.dislikes,
  });

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(
      imageId: json['imageId'],
      placeId: json['placeId'],
      imageUrl: json['imageUrl'],
      uploadedById: json['uploadedById'],
      uploaderUsername: json['uploaderUsername'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      isApproved: json['isApproved'] ?? false,
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
