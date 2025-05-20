class Place {
  final int placeId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  Place({
    required this.placeId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      placeId: json['placeId'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      imageUrl: json['imageUrl'],
    );
  }
}
