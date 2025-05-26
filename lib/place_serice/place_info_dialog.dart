import 'package:flutter/material.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/place_serice/place_image_service.dart';
import 'package:gather_club/place_serice/rating_state_service.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;

class PlaceInfoDialog extends StatelessWidget {
  final Place place;
  final bool isLoading;
  final List<PlaceImage>? initialImages;
  final Function(Map<String, dynamic>)? onRouteBuilt;
  final Function()? onRouteCleared;
  final AppLatLong location;

  const PlaceInfoDialog({
    super.key,
    required this.place,
    this.initialImages,
    this.isLoading = false,
    this.onRouteBuilt,
    this.onRouteCleared,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: isLoading
              ? _buildShimmer()
              : _PlaceContent(
                  place: place,
                  initialImages: initialImages,
                  onRouteBuilt: onRouteBuilt,
                  onRouteCleared: onRouteCleared,
                  location: location,
                  scrollController: scrollController,
                ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar для DraggableScrollableSheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Placeholder для изображений
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder для названия и категории
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 24,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Placeholder для описания
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceContent extends StatefulWidget {
  final Place place;
  final List<PlaceImage>? initialImages;
  final Function(Map<String, dynamic>)? onRouteBuilt;
  final Function()? onRouteCleared;
  final AppLatLong location;
  final ScrollController scrollController;

  const _PlaceContent({
    required this.place,
    required this.initialImages,
    this.onRouteBuilt,
    this.onRouteCleared,
    required this.location,
    required this.scrollController,
  });

  @override
  State<_PlaceContent> createState() => _PlaceContentState();
}

class _PlaceContentState extends State<_PlaceContent>
    with SingleTickerProviderStateMixin {
  late PlaceImageService _imageService;
  late RatingStateService _ratingStateService;
  late List<PlaceImage> _images;
  int _currentImageIndex = 0;
  bool _isLoadingImages = false;
  bool _isRating = false;
  bool _routeBuilt = false;
  bool _isLoadingRoute = false;
  bool _hasLiked = false;
  bool _hasDisliked = false;
  final ImagePicker _picker = ImagePicker();
  late int _userId;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _imageService = PlaceImageService(authProvider);
    _ratingStateService = RatingStateService();
    _images = widget.initialImages ?? [];
    _initializeUserId();
    if (_images.isEmpty) {
      _loadImages();
    } else {
      _initializeRatingStates();
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });
  }

  Future<void> _initializeUserId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userId = await authProvider.getUserId();
  }

  void _initializeRatingStates() async {
    if (_images.isEmpty) return;

    for (var image in _images) {
      try {
        if (!_ratingStateService.hasRating(_userId, image.imageId)) {
          final ratings =
              await _imageService.getRatingState(image.imageId, _userId);

          _ratingStateService.setRatingState(_userId, image.imageId, {
            'likes': image.likes,
            'dislikes': image.dislikes,
            'liked': ratings['liked'] ?? false,
            'disliked': ratings['disliked'] ?? false,
          });
        }

        final state =
            _ratingStateService.getRatingState(_userId, image.imageId);
        if (state != null && mounted) {
          setState(() {
            image.likes = state['likes'];
            image.dislikes = state['dislikes'];
            if (_currentImageIndex < _images.length &&
                _images[_currentImageIndex].imageId == image.imageId) {
              _hasLiked = state['liked'];
              _hasDisliked = state['disliked'];
            }
          });
        }
      } catch (e) {
        print('Error initializing rating state for image ${image.imageId}: $e');
      }
    }
  }

  void _updateCurrentImageRatingState() {
    if (_currentImageIndex >= _images.length) return;

    final currentImageId = _images[_currentImageIndex].imageId;
    final state = _ratingStateService.getRatingState(_userId, currentImageId);

    if (state != null && mounted) {
      setState(() {
        _hasLiked = state['liked'];
        _hasDisliked = state['disliked'];
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PlaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImages != oldWidget.initialImages) {
      _images = widget.initialImages ?? [];
      _initializeRatingStates();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    if (!mounted) return;

    setState(() => _isLoadingImages = true);
    try {
      final images = await _imageService.getPlaceImages(widget.place.placeId);
      if (mounted) {
        setState(() {
          _images = images;
          _isLoadingImages = false;
        });
        _initializeRatingStates();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки изображений: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // TODO: Здесь должна быть логика загрузки изображения на сервер
      // и получения URL. Сейчас это заглушка.
      final String imageUrl = "http://example.com/image.jpg";

      final uploadedImage = await _imageService.uploadImage(
        widget.place.placeId,
        imageUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Изображение загружено и ожидает проверки'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки изображения: $e')),
      );
    }
  }

  Future<void> _buildRoute() async {
    if (!mounted) return;

    setState(() => _isLoadingRoute = true);

    try {
      // Имитация данных маршрута
      final routeInfo = {
        'origin': {
          'lat': widget.location.lat,
          'lng': widget.location.long
        }, // Текущее местоположение
        'destination': {
          'lat': widget.place.latitude,
          'lng': widget.place.longitude
        },
        'polyline': 'fake_polyline_data',
        'duration': '15 мин',
        'distance': '2.5 км',
      };

      // Небольшая задержка для имитации построения маршрута
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _routeBuilt = true;
          _isLoadingRoute = false;
        });

        widget.onRouteBuilt?.call(routeInfo);

        // Закрываем диалог после успешного построения маршрута
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка построения маршрута: $e')),
        );
      }
    }
  }

  void _clearRoute() {
    setState(() => _routeBuilt = false);
    widget.onRouteCleared?.call();
  }

  Widget _buildImageProgressBar() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(_images.length, (index) {
          final isActive = index == _currentImageIndex;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar для DraggableScrollableSheet
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Карусель фотографий
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    children: [
                      if (_images.isNotEmpty) _buildImageProgressBar(),
                      Stack(
                        children: [
                          SizedBox(
                            height: 250,
                            child: _isLoadingImages
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _images.isNotEmpty
                                    ? PageView.builder(
                                        itemCount: _images.length,
                                        onPageChanged: (index) {
                                          if (mounted) {
                                            setState(() {
                                              _currentImageIndex = index;
                                              _updateCurrentImageRatingState();
                                            });
                                          }
                                        },
                                        itemBuilder: (context, index) {
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                              _images[index].imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.error_outline,
                                                      size: 50,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                );
                                              },
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                if (progress == null)
                                                  return child;
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: progress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? progress
                                                                .cumulativeBytesLoaded /
                                                            progress
                                                                .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      )
                                    : _buildNoImagesPlaceholder(),
                          ),
                          if (_images.isNotEmpty)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Column(
                                children: [
                                  FloatingActionButton(
                                    heroTag: 'like_btn',
                                    onPressed: _isRating
                                        ? null
                                        : () => _rateImage(true),
                                    backgroundColor: Colors.white,
                                    mini: true,
                                    child: _isRating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.thumb_up,
                                            color: Colors.green),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton(
                                    heroTag: 'dislike_btn',
                                    onPressed: _isRating
                                        ? null
                                        : () => _rateImage(false),
                                    backgroundColor: Colors.white,
                                    mini: true,
                                    child: _isRating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.thumb_down,
                                            color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_images.isNotEmpty && _currentImageIndex < _images.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _buildImageStats(_images[_currentImageIndex]),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: _buildPlaceInfo(),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: _buildActionButtons(),
        ),
      ],
    );
  }

  Future<void> _rateImage(bool isLike) async {
    if (_isRating || _images.isEmpty) return;

    setState(() => _isRating = true);

    try {
      final currentImage = _images[_currentImageIndex];
      final currentImageId = currentImage.imageId;
      final currentState =
          _ratingStateService.getRatingState(_userId, currentImageId);

      // Если уже стоит такая же оценка - выходим
      if ((isLike && _ratingStateService.hasLiked(_userId, currentImageId)) ||
          (!isLike &&
              _ratingStateService.hasDisliked(_userId, currentImageId))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isLike
                  ? 'Вы уже поставили лайк'
                  : 'Вы уже поставили дизлайк')),
        );
        return;
      }

      // Получаем текущие значения счетчиков
      int currentLikes = currentState?['likes'] ?? currentImage.likes;
      int currentDislikes = currentState?['dislikes'] ?? currentImage.dislikes;

      // Обновляем состояние и UI
      if (isLike) {
        // Если был дизлайк - убираем его
        if (_ratingStateService.hasDisliked(_userId, currentImageId)) {
          await _imageService.removeDislike(currentImageId);
          currentDislikes = math.max<int>(0, currentDislikes - 1);
        }
        // Ставим лайк
        await _imageService.addLike(currentImageId);
        currentLikes += 1;

        _ratingStateService.setRatingState(_userId, currentImageId, {
          'likes': currentLikes,
          'dislikes': currentDislikes,
          'liked': true,
          'disliked': false,
        });
      } else {
        // Если был лайк - убираем его
        if (_ratingStateService.hasLiked(_userId, currentImageId)) {
          await _imageService.removeLike(currentImageId);
          currentLikes = math.max<int>(0, currentLikes - 1);
        }
        // Ставим дизлайк
        await _imageService.addDislike(currentImageId);
        currentDislikes += 1;

        _ratingStateService.setRatingState(_userId, currentImageId, {
          'likes': currentLikes,
          'dislikes': currentDislikes,
          'liked': false,
          'disliked': true,
        });
      }

      // Обновляем UI
      if (mounted) {
        setState(() {
          currentImage.likes = currentLikes;
          currentImage.dislikes = currentDislikes;
          _hasLiked = isLike;
          _hasDisliked = !isLike;
        });
      }

      _animationController.forward();
    } catch (e) {
      print('Error during rating operation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выполнить действие: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRating = false);
      }
    }
  }

  Widget _buildNoImagesPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Нет фотографий',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStats(PlaceImage image) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _hasLiked ? _scaleAnimation.value : 1.0,
                child: Icon(
                  Icons.thumb_up,
                  size: 16,
                  color: _hasLiked ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text('${image.likes}'),
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _hasDisliked ? _scaleAnimation.value : 1.0,
                child: Icon(
                  Icons.thumb_down,
                  size: 16,
                  color: _hasDisliked ? Colors.red : Colors.grey,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text('${image.dislikes}'),
        ],
      ),
    );
  }

  Widget _buildPlaceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Название и категория
        Row(
          children: [
            Expanded(
              child: Text(
                widget.place.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.place.category ?? 'Категория',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Описание
        if (widget.place.description != null &&
            widget.place.description!.isNotEmpty)
          Text(
            widget.place.description!,
            style: const TextStyle(fontSize: 16),
          ),
        const SizedBox(height: 16),

        // Адрес
        if (widget.place.address != null && widget.place.address!.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.place.address!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        if (widget.place.address != null && widget.place.address!.isNotEmpty)
          const SizedBox(height: 16),

        // Время работы и телефон
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.place.workingHours ?? '9:00 - 22:00',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.phone, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.place.phone ?? '+7 (XXX) XXX-XX-XX',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.directions,
          onPressed: (_routeBuilt || _isLoadingRoute) ? null : _buildRoute,
          isLoading: _isLoadingRoute,
        ),
        _buildActionButton(
          icon: Icons.add_a_photo,
          onPressed: _uploadImage,
        ),
        _buildActionButton(
          icon: Icons.monetization_on,
          onPressed: () {
            // TODO: Реализовать получение монет
          },
        ),
        _buildActionButton(
          icon: Icons.group_add,
          onPressed: () {
            Navigator.of(context).pushNamed('/chat');
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: onPressed == null
            ? Colors.grey[300]
            : Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
