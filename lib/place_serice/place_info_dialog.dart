import 'package:flutter/material.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:gather_club/place_serice/place.dart';

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

class _PlaceContentState extends State<_PlaceContent> {
  late List<PlaceImage> _images;
  int _currentImageIndex = 0;
  bool _isLoadingImages = false;
  bool _isRating = false;
  bool _routeBuilt = false;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _images = widget.initialImages ?? [];
    if (_images.isEmpty) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    if (!mounted) return;

    setState(() => _isLoadingImages = true);
    try {
      // Здесь должен быть вызов API для загрузки изображений
      // Для примера просто имитируем загрузку
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _isLoadingImages = false);
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
                                            setState(() =>
                                                _currentImageIndex = index);
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
    // if (_isRating || _images.isEmpty) return;

    // setState(() => _isRating = true);

    // try {
    //   // Имитация API вызова для оценки изображения
    //   await Future.delayed(const Duration(milliseconds: 500));

    //   if (mounted) {
    //     setState(() {
    //       if (isLike) {
    //         _images[_currentImageIndex].likes++;
    //       } else {
    //         _images[_currentImageIndex].dislikes++;
    //       }
    //       _isRating = false;
    //     });
    //   }
    // } catch (e) {
    //   if (mounted) {
    //     setState(() => _isRating = false);
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text('Ошибка при оценке: $e')),
    //     );
    //   }
    // }
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
          const Icon(Icons.thumb_up, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text('${image.likes}'),
          const SizedBox(width: 16),
          const Icon(Icons.thumb_down, size: 16, color: Colors.red),
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
          onPressed: () {
            // TODO: Реализовать добавление фото
          },
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
            // TODO: Реализовать создание встречи
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
