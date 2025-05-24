import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/auth_service/auth_service.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/place_serice/place_info_dialog.dart';
import 'package:gather_club/place_serice/place_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage>
    with AutomaticKeepAliveClientMixin {
  final LocationService _locationService = LocationService();
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  List<Place> _places = [];
  AuthService _authService = AuthService();
  PolylineMapObject? _routePolyline;
  PlacemarkMapObject? _destinationPlacemark;
  String? _routeDuration;
  String? _routeDistance;
  bool _isRouteCalculating = false;
  AppLatLong? location;
  Point? _lastCameraPosition;
  PlacemarkMapObject? _tempPlacemark;
  TextEditingController _placeNameController = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchPlaces();
  }

  void _saveCameraPosition() {
    _mapController.getCameraPosition().then((position) {
      _lastCameraPosition = position.target;
    });
  }

// Восстанавливаем позицию при возврате
  void _restoreCameraPosition() {
    if (_lastCameraPosition != null) {
      _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _lastCameraPosition!, zoom: 15),
        ),
      );
    }
  }

  Future<void> _fetchPlaces() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    print("token: $token");
    final location = await _locationService.getCurrentLocation();

    try {
      final response = await http.get(
        Uri.parse(
            'http://212.67.8.92:8080/places/nearby?lat=${location.lat}&lng=${location.long}&radiusKm=10'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> placesJson = json.decode(response.body);
        setState(() {
          _places = placesJson.map((json) => Place.fromJson(json)).toList();
          _addPlacesToMap();
        });
      } else {
        print('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching places: $e');
    }
  }

  void _addPlacesToMap() async {
    final placemarks = <PlacemarkMapObject>[];
    final _authProvider = Provider.of<AuthProvider>(context, listen: false);

    for (final place in _places) {
      // Размер миниатюры (в пикселях)
      const thumbnailSize = 100;
      PlaceRepository placeRepository = PlaceRepository(_authProvider);
      List<PlaceImage> placeImages =
          await placeRepository.fetchPlaceImages(place.placeId);
      // Создаём закруглённую квадратную миниатюру
      final Uint8List? thumbnailBytes = place.imageUrl != null
          ? await _createRoundedThumbnail(place.imageUrl!, thumbnailSize)
          : null;

      placemarks.add(PlacemarkMapObject(
        mapId: MapObjectId('place_${place.placeId}'),
        point: Point(latitude: place.latitude, longitude: place.longitude),
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: thumbnailBytes != null
                ? BitmapDescriptor.fromBytes(thumbnailBytes)
                : BitmapDescriptor.fromAssetImage('assets/logo.png'),
            scale: 1.0, // Масштаб 1:1, так как мы уже подготовили изображение
          ),
        ),
        opacity: 1,
        onTap: (mapObject, point) {
          _showPlaceInfo(place, placeImages, location!);
        },
      ));
    }

    setState(() {
      _mapObjects.addAll(placemarks);
    });
  }

  Future<Uint8List?> _createRoundedThumbnail(String imageUrl, int size) async {
    try {
      // Загружаем изображение
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      var image = frame.image;

      // Обрезаем до квадрата
      final cropSize = min(image.width, image.height);
      final offsetX = (image.width - cropSize) ~/ 2;
      final offsetY = (image.height - cropSize) ~/ 2;

      image = await _cropImage(
        image,
        offsetX,
        offsetY,
        cropSize,
        cropSize,
      );

      // Масштабируем до нужного размера
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Создаём путь для закруглённого прямоугольника
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
          Radius.circular(size * 0.2), // Закругление 20% от размера
        ));

      // Рисуем изображение с закруглёнными углами
      canvas.clipPath(path);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint(),
      );

      // Конвертируем в байты
      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error creating thumbnail: $e');
      return null;
    }
  }

  Future<ui.Image> _cropImage(
    ui.Image image,
    int x,
    int y,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
          x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  void _showPlaceInfo(
      Place place, List<PlaceImage> placeImages, AppLatLong location) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceInfoDialog(
        place: place,
        initialImages: placeImages,
        onRouteBuilt: (routeInfo) => _buildRoute(place, routeInfo, location),
        onRouteCleared: _clearRoute,
        location: location,
      ),
    );
  }

  // Исправленный метод для запроса пешеходного маршрута
  Future<PedestrianSessionResult> _requestPedestrianRoute(
      Point startPoint, Point endPoint) async {
    final points = [
      RequestPoint(
        point: startPoint,
        requestPointType: RequestPointType.wayPoint,
      ),
      RequestPoint(
        point: endPoint,
        requestPointType: RequestPointType.wayPoint,
      ),
    ];

    // Дожидаемся выполнения и получаем кортеж
    final (session, resultFuture) = await YandexPedestrian.requestRoutes(
        points: points,
        // Новый формат параметров
        avoidSteep: true,
        timeOptions: TimeOptions() // Избегать крутых подъемов
        );

    // Теперь ждем выполнения Future<PedestrianSessionResult>
    return await resultFuture;
  }

// Исправленный метод построения пешеходного маршрута
  Future<void> _buildRoute(
      Place place, Map<String, dynamic> routeInfo, AppLatLong location) async {
    setState(() => _isRouteCalculating = true);

    try {
      final startPoint =
          Point(latitude: location.lat, longitude: location.long);
      final endPoint =
          Point(latitude: place.latitude, longitude: place.longitude);

      final result = await _requestPedestrianRoute(startPoint, endPoint);

      if (result.routes != null && result.routes!.isNotEmpty) {
        final route = result.routes!.first;

        // Получаем данные о пешеходном маршруте (новый формат)
        final timeText = route.metadata.weight.time.text;
        final distanceText = route.metadata.weight.walkingDistance.text;

        // Обновляем данные маршрута
        setState(() {
          _routeDuration = timeText;
          _routeDistance = distanceText;
        });

        // Остальной код остается без изменений
        final routePolyline = PolylineMapObject(
          mapId: const MapObjectId('current_route'),
          polyline: Polyline(points: route.geometry.points),
          strokeColor: Colors.green.withOpacity(0.8),
          strokeWidth: 4,
          outlineColor: Colors.white,
          outlineWidth: 1.5,
          dashLength: 8,
          gapLength: 4,
        );

        final destinationPlacemark = PlacemarkMapObject(
          mapId: const MapObjectId('route_destination'),
          point: endPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/walking_destination.png'),
              scale: 0.5,
            ),
          ),
        );

        setState(() {
          _routePolyline = routePolyline;
          _destinationPlacemark = destinationPlacemark;
        });

        _updateMapObjects();
        await _showRouteOnMap(route.geometry.points);
      } else {
        throw Exception('Не удалось построить пешеходный маршрут');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Ошибка построения пешеходного маршрута: ${e.toString()}')),
      );
    } finally {
      setState(() => _isRouteCalculating = false);
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    if (duration.inHours > 0) {
      return '${duration.inHours} ч ${duration.inMinutes.remainder(60)} мин пешком';
    } else {
      return '${duration.inMinutes} мин пешком';
    }
  }

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} км';
    } else {
      return '${meters.toInt()} м';
    }
  }

  void _clearRoute() {
    setState(() {
      _routePolyline = null;
      _destinationPlacemark = null;
      _routeDuration = null;
      _routeDistance = null;
    });
    _updateMapObjects();
  }

  void _updateMapObjects() {
    setState(() {
      // Удаляем старые объекты маршрута
      _mapObjects.removeWhere((obj) =>
          obj.mapId.value == 'current_route' ||
          obj.mapId.value == 'route_destination');

      // Добавляем новые
      if (_routePolyline != null) {
        _mapObjects.add(_routePolyline!);
      }
      if (_destinationPlacemark != null) {
        _mapObjects.add(_destinationPlacemark!);
      }
    });
  }

  Future<void> _showRouteOnMap(List<Point> routePoints) async {
    if (routePoints.isEmpty) return;

    // Находим границы маршрута для оптимального отображения
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLon = routePoints.first.longitude;
    double maxLon = routePoints.first.longitude;

    for (final point in routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }

    // Вычисляем центр и зум для отображения всего маршрута
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;

    // Расчет подходящего зума на основе размера маршрута
    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = max(latDiff, lonDiff);

    double zoom;
    if (maxDiff > 0.1) {
      zoom = 11;
    } else if (maxDiff > 0.05) {
      zoom = 13;
    } else if (maxDiff > 0.01) {
      zoom = 15;
    } else {
      zoom = 16;
    }

    await _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: centerLat, longitude: centerLon),
          zoom: zoom,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.5,
      ),
    );
  }

  Future<void> _initLocation() async {
    _hasLocationPermission = await _locationService.hasLocationPermission();
    if (!_hasLocationPermission) {
      final permission = await _locationService.requestPermission();
      _hasLocationPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    }

    if (_hasLocationPermission) {
      await _moveToCurrentLocation();
    } else {
      await _moveToDefaultLocation();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      location = await _locationService.getCurrentLocation();
      await _updateCamera(location!.lat, location!.long);
      _addUserPlacemark(location!.lat, location!.long);
      // Обновляем места при изменении позиции
      await _fetchPlaces();
    } catch (e) {
      await _moveToDefaultLocation();
    }
  }

  Future<void> _moveToDefaultLocation() async {
    await _updateCamera(
      _locationService.defLocation.lat,
      _locationService.defLocation.long,
    );
  }

  Future<void> _updateCamera(double lat, double long) async {
    if (_mapController != null) {
      await _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: lat, longitude: long),
            zoom: 15,
          ),
        ),
        animation:
            const MapAnimation(type: MapAnimationType.linear, duration: 1),
      );
    }
  }

  void _addUserPlacemark(double lat, double long) {
    final placemark = PlacemarkMapObject(
      opacity: 1,
      mapId: const MapObjectId('user_location'),
      point: Point(latitude: lat, longitude: long),
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/pin.png'),
          scale: 0.2,
        ),
      ),
    );

    setState(() {
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'user_location');
      _mapObjects.add(placemark);
    });
  }

  void _handleMapLongPress(Point point) async {
    // Создаем временную метку
    final tempPlacemark = PlacemarkMapObject(
      mapId: const MapObjectId('temp_placemark'),
      point: point,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/logo.png'),
          scale: 0.8,
          anchor: const Offset(0.5, 0.5),
          rotationType: RotationType.noRotation,
        ),
      ),
      opacity: 1.0,
    );

    setState(() {
      // Удаляем предыдущую временную метку, если она существует
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'temp_placemark');
      _mapObjects.add(tempPlacemark);
      _tempPlacemark = tempPlacemark;
    });

    _showInteractionMenu(point);
  }

  void _showInteractionMenu(Point point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _placeNameController,
                    decoration: InputDecoration(
                      labelText: 'Название места',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setState(
                          () {}); // Обновляем состояние при изменении текста
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (location != null) {
                        _buildRoute(
                          Place(
                            placeId: 0,
                            name: _placeNameController.text,
                            description: '',
                            latitude: point.latitude,
                            longitude: point.longitude,
                            imageUrl: null,
                          ),
                          {},
                          location!,
                        );
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Построить маршрут'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Реализовать сохранение метки
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Сохранить метку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Реализовать создание встречи
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Создать встречу'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Удаляем временную метку при закрытии меню
      setState(() {
        if (_tempPlacemark != null) {
          _mapObjects.removeWhere((obj) => obj.mapId.value == 'temp_placemark');
          _tempPlacemark = null;
        }
        _placeNameController.clear();
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Интересные места'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _hasLocationPermission ? _moveToCurrentLocation : null,
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchPlaces,
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _authService.logout,
            ),
          // Кнопка очистки маршрута
          if (_routePolyline != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearRoute,
            ),
        ],
      ),
      body: Stack(
        children: [
          YandexMap(
            nightModeEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;
              if (_isLoading && _hasLocationPermission) {
                await _moveToCurrentLocation();
              }
            },
            onMapLongTap: (Point point) {
              _handleMapLongPress(point);
            },
            mapObjects: _mapObjects,
            mapType: MapType.vector,
          ),
          if (_isLoading || _isRouteCalculating)
            const Center(child: CircularProgressIndicator()),
          // Панель информации о пешеходном маршруте
          if (_routeDuration != null && _routeDistance != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 100,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Пешеходный маршрут',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Расстояние: $_routeDistance',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Время: $_routeDuration',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearRoute,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'location',
            child: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _hasLocationPermission
                        ? 'Разрешение на геолокацию получено'
                        : 'Нет разрешения на геолокацию',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'places',
            child: const Icon(Icons.place),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Найдено ${_places.length} мест'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
