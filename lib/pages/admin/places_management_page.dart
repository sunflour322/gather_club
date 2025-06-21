import 'package:flutter/material.dart';
import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:gather_club/api_services/admin_service.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:gather_club/pages/admin/place_form_dialog.dart';
import 'package:gather_club/widgets/custom_notification.dart';

class PlacesManagementPage extends StatefulWidget {
  final AdminService adminService;

  const PlacesManagementPage({Key? key, required this.adminService})
      : super(key: key);

  @override
  State<PlacesManagementPage> createState() => _PlacesManagementPageState();
}

class _PlacesManagementPageState extends State<PlacesManagementPage> {
  List<Place> _places = [];
  bool _isLoading = true;
  String? _error;
  Map<int, bool> _expandedPlaces = {};
  Map<int, List<PlaceImage>> _placeImages = {};
  Map<int, bool> _loadingImages = {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final places = await widget.adminService.getAllPlaces();
      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки мест: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlaceImages(int placeId) async {
    if (_loadingImages[placeId] == true) return;

    setState(() {
      _loadingImages[placeId] = true;
    });

    try {
      final images = await widget.adminService.getPendingImages();
      final placeImages =
          images.where((img) => img.placeId == placeId).toList();

      setState(() {
        _placeImages[placeId] = placeImages;
        _loadingImages[placeId] = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки изображений: $e';
        _loadingImages[placeId] = false;
      });
    }
  }

  Future<void> _approveImage(int imageId) async {
    try {
      await widget.adminService.approveImage(imageId);

      // Обновляем список изображений для всех мест
      for (var placeId in _placeImages.keys) {
        _placeImages[placeId] = _placeImages[placeId]!
            .where((img) => img.imageId != imageId)
            .toList();
      }

      setState(() {});

      CustomNotification.show(context, 'Изображение одобрено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка: $e');
    }
  }

  Future<void> _rejectImage(int imageId) async {
    try {
      await widget.adminService.rejectImage(imageId);

      // Обновляем список изображений для всех мест
      for (var placeId in _placeImages.keys) {
        _placeImages[placeId] = _placeImages[placeId]!
            .where((img) => img.imageId != imageId)
            .toList();
      }

      setState(() {});

      CustomNotification.show(context, 'Изображение отклонено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка: $e');
    }
  }

  Future<void> _deletePlace(int placeId) async {
    try {
      await widget.adminService.deletePlace(placeId);
      setState(() {
        _places.removeWhere((place) => place.placeId == placeId);
      });
      CustomNotification.show(context, 'Место удалено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка удаления: $e');
    }
  }

  void _showCreatePlaceDialog() {
    Navigator.pushNamed(
      context,
      '/admin/place/create',
      arguments: {
        'onSave': _createPlace,
      },
    );
  }

  void _showEditPlaceDialog(Place place) {
    Navigator.pushNamed(
      context,
      '/admin/place/edit',
      arguments: {
        'place': place,
        'onSave': (placeData) => _updatePlace(place.placeId, placeData),
      },
    );
  }

  Future<void> _createPlace(Map<String, dynamic> placeData) async {
    try {
      await widget.adminService.createPlace(placeData);
      _loadPlaces(); // Перезагружаем список мест
      CustomNotification.show(context, 'Место создано');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка создания: $e');
    }
  }

  Future<void> _updatePlace(int placeId, Map<String, dynamic> placeData) async {
    try {
      await widget.adminService.updatePlace(placeId, placeData);
      _loadPlaces(); // Перезагружаем список мест
      CustomNotification.show(context, 'Место обновлено');
    } catch (e) {
      CustomNotification.show(context, 'Ошибка обновления: $e');
    }
  }

  void _toggleExpanded(int placeId) {
    setState(() {
      _expandedPlaces[placeId] = !(_expandedPlaces[placeId] ?? false);
    });

    if (_expandedPlaces[placeId] == true) {
      _loadPlaceImages(placeId);
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
              onPressed: _loadPlaces,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPlaces,
        child: _places.isEmpty
            ? const Center(child: Text('Нет доступных мест'))
            : ListView.builder(
                itemCount: _places.length,
                itemBuilder: (context, index) {
                  final place = _places[index];
                  final isExpanded = _expandedPlaces[place.placeId] ?? false;

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: place.imageUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(place.imageUrl!),
                                  onBackgroundImageError: (_, __) {
                                    // Обработка ошибки загрузки изображения
                                  },
                                )
                              : CircleAvatar(
                                  backgroundColor: AppTheme.accentColor,
                                  child: const Icon(Icons.place,
                                      color: Colors.white),
                                ),
                          title: Text(place.name),
                          subtitle: Text(place.address ?? 'Адрес не указан'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditPlaceDialog(place),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deletePlace(place.placeId),
                              ),
                              IconButton(
                                icon: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                onPressed: () => _toggleExpanded(place.placeId),
                              ),
                            ],
                          ),
                        ),
                        if (isExpanded) _buildExpandedContent(place.placeId),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaceDialog,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpandedContent(int placeId) {
    final isLoading = _loadingImages[placeId] ?? false;
    final images = _placeImages[placeId] ?? [];

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (images.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Нет ожидающих модерации изображений')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Изображения на модерации:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                children: [
                  Image.network(
                    image.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.error, size: 50),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Загрузил: ${image.uploaderUsername}'),
                            Text(
                                'Дата: ${image.uploadedAt.toString().substring(0, 16)}'),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _approveImage(image.imageId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _rejectImage(image.imageId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
