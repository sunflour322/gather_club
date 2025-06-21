import 'package:flutter/material.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/api_services/place_serice/place_image_service.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/widgets/custom_notification.dart';

class PendingImagesPage extends StatefulWidget {
  final AdminService adminService;

  const PendingImagesPage({Key? key, required this.adminService})
      : super(key: key);

  @override
  State<PendingImagesPage> createState() => _PendingImagesPageState();
}

class _PendingImagesPageState extends State<PendingImagesPage> {
  List<PlaceImage> _pendingImages = [];
  bool _isLoading = true;
  String? _error;
  Map<int, Place> _placesCache = {};

  @override
  void initState() {
    super.initState();
    _loadPendingImages();
  }

  Future<void> _loadPendingImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final images = await widget.adminService.getPendingImages();
      setState(() {
        _pendingImages = images;
        _isLoading = false;
      });

      // Загружаем информацию о местах для каждого изображения
      for (var image in images) {
        if (!_placesCache.containsKey(image.placeId)) {
          _loadPlaceInfo(image.placeId);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки изображений: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlaceInfo(int placeId) async {
    try {
      final place = await widget.adminService.getPlaceById(placeId);
      setState(() {
        _placesCache[placeId] = place;
      });
    } catch (e) {
      print('Ошибка загрузки информации о месте $placeId: $e');
    }
  }

  Future<void> _approveImage(int imageId) async {
    try {
      await widget.adminService.approveImage(imageId);
      setState(() {
        _pendingImages.removeWhere((img) => img.imageId! == imageId);
      });
      CustomNotification.show(context, 'Изображение одобрено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка: $e');
    }
  }

  Future<void> _rejectImage(int imageId) async {
    try {
      await widget.adminService.rejectImage(imageId);
      setState(() {
        _pendingImages.removeWhere((img) => img.imageId! == imageId);
      });
      CustomNotification.show(context, 'Изображение отклонено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingImages,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_pendingImages.isEmpty) {
      return const Center(
        child: Text('Нет изображений, ожидающих модерации'),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPendingImages,
        child: ListView.builder(
          itemCount: _pendingImages.length,
          itemBuilder: (context, index) {
            final image = _pendingImages[index];
            final place = _placesCache[image.placeId];

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: AppTheme.accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Image.network(
                    image.imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error, size: 50),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Загрузил: ${image.uploaderUsername}'),
                        Text(
                            'Дата: ${image.uploadedAt.toString().substring(0, 16)}'),
                        Text(
                            'Лайки: ${image.likes}, Дизлайки: ${image.dislikes}'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Одобрить'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _approveImage(image.imageId!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Отклонить'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _rejectImage(image.imageId!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
