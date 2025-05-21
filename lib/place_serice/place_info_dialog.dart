import 'package:flutter/material.dart';
import 'package:gather_club/place_serice/place.dart';

class PlaceInfoDialog extends StatelessWidget {
  final Place place;
  final bool isLoading;
  final List<PlaceImage>? initialImages;
  final Function(Map<String, dynamic>)? onRouteBuilt;
  final Function()? onRouteCleared;

  const PlaceInfoDialog({
    super.key,
    required this.place,
    this.initialImages,
    this.isLoading = false,
    this.onRouteBuilt,
    this.onRouteCleared,
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
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? _buildShimmer()
              : _PlaceContent(
                  place: place,
                  initialImages: initialImages,
                  onRouteBuilt: onRouteBuilt,
                  onRouteCleared: onRouteCleared,
                ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}

class _PlaceContent extends StatefulWidget {
  final Place place;
  final List<PlaceImage>? initialImages;
  final Function(Map<String, dynamic>)? onRouteBuilt;
  final Function()? onRouteCleared;

  const _PlaceContent({
    required this.place,
    required this.initialImages,
    this.onRouteBuilt,
    this.onRouteCleared,
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

  @override
  void initState() {
    super.initState();
    _images = widget.initialImages ?? [];
    if (_images.isEmpty) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    setState(() => _isLoadingImages = true);
    try {
      // Здесь должен быть вызов API для загрузки изображений
      // Для примера просто имитируем загрузку
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoadingImages = false);
    } catch (e) {
      setState(() => _isLoadingImages = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки изображений: $e')),
      );
    }
  }

  Future<void> _buildRoute() async {
    try {
      // Имитация данных маршрута
      final routeInfo = {
        'origin': {
          'lat': 55.751244,
          'lng': 37.618423
        }, // Текущее местоположение (заглушка)
        'destination': {
          'lat': widget.place.latitude,
          'lng': widget.place.longitude
        },
        'polyline': 'fake_polyline_data',
        'duration': '15 мин',
        'distance': '2.5 км',
      };

      setState(() => _routeBuilt = true);
      widget.onRouteBuilt?.call(routeInfo);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Маршрут построен')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка построения маршрута: $e')),
      );
    }
  }

  void _clearRoute() {
    setState(() => _routeBuilt = false);
    widget.onRouteCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = _images.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Карусель фотографий
        Stack(
          children: [
            SizedBox(
              height: 250,
              child: _isLoadingImages
                  ? const Center(child: CircularProgressIndicator())
                  : hasImages
                      ? PageView.builder(
                          itemCount: _images.length,
                          onPageChanged: (index) =>
                              setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _images[index].imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
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

            // Кнопки лайка/дизлайка
            if (hasImages)
              Positioned(
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'like_btn',
                      onPressed: _isRating ? null : () {},
                      backgroundColor: Colors.white,
                      child: _isRating
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.thumb_up, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton(
                      heroTag: 'dislike_btn',
                      onPressed: _isRating ? null : () {},
                      backgroundColor: Colors.white,
                      child: _isRating
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.thumb_down, color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // Статистика изображения
        if (hasImages) _buildImageStats(_images[_currentImageIndex]),

        // Информация о месте
        _buildPlaceInfo(),

        // Кнопки действий
        _buildActionButtons(),
      ],
    );
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
            Text('Нет фотографий'),
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
        if (widget.place.description != null)
          Text(
            widget.place.description!,
            style: const TextStyle(fontSize: 16),
          ),
        const SizedBox(height: 16),

        // Время работы и телефон
        Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 8),
            Text(
              widget.place.workingHours ?? '9:00 - 22:00',
              style: const TextStyle(fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.phone, size: 16),
            const SizedBox(width: 8),
            Text(
              widget.place.phone ?? '+7 (XXX) XXX-XX-XX',
              style: const TextStyle(fontSize: 14),
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
          label: 'Маршрут',
          onPressed: _routeBuilt ? null : _buildRoute,
        ),
        _buildActionButton(
          icon: Icons.add_a_photo,
          label: 'Добавить фото',
          onPressed: () {},
        ),
        _buildActionButton(
          icon: Icons.monetization_on,
          label: 'Получить монеты',
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: onPressed == null ? Colors.grey : Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed == null ? Colors.grey : Colors.black,
          ),
        ),
      ],
    );
  }
}
