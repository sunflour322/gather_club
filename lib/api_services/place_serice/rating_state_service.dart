import 'package:gather_club/api_services/auth_service/auth_provider.dart';

class RatingStateService {
  static final RatingStateService _instance = RatingStateService._internal();
  final Map<String, Map<String, dynamic>> _imageStates = {};

  factory RatingStateService() {
    return _instance;
  }

  RatingStateService._internal();

  String _getKey(int userId, int imageId) => '$userId-$imageId';

  bool hasRating(int userId, int imageId) {
    final key = _getKey(userId, imageId);
    return _imageStates.containsKey(key);
  }

  Map<String, dynamic>? getRatingState(int userId, int imageId) {
    final key = _getKey(userId, imageId);
    return _imageStates[key];
  }

  void setRatingState(int userId, int imageId, Map<String, dynamic> state) {
    final key = _getKey(userId, imageId);
    _imageStates[key] = state;
  }

  bool hasLiked(int userId, int imageId) {
    final state = getRatingState(userId, imageId);
    return state?['liked'] ?? false;
  }

  bool hasDisliked(int userId, int imageId) {
    final state = getRatingState(userId, imageId);
    return state?['disliked'] ?? false;
  }

  void clear() {
    _imageStates.clear();
  }
}
