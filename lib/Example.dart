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

class _ExamplePageState extends State<ExamplePage> {
  final LocationService _locationService = LocationService();
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  List<Place> _places = [];
  AuthService _authService = new AuthService();
  PolylineMapObject? _routePolyline;
  PlacemarkMapObject? _destinationPlacemark;
  String? _routeDuration;
  String? _routeDistance;
  bool _isRouteCalculating = false;
  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchPlaces();
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
          _showPlaceInfo(place, placeImages);
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

  void _showPlaceInfo(Place place, List<PlaceImage> placeImages) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceInfoDialog(
        place: place,
        initialImages: placeImages,
        onRouteBuilt: (routeInfo) => _buildRoute(place, routeInfo),
        onRouteCleared: _clearRoute,
      ),
    );
  }

  Future<void> _buildRoute(Place place, Map<String, dynamic> routeInfo) async {
    setState(() {
      _isRouteCalculating = true;
      _routeDuration = routeInfo['duration'];
      _routeDistance = routeInfo['distance'];
    });

    try {
      // Получаем текущее местоположение
      final currentLocation = await _locationService.getCurrentLocation();

      // Создаем полилинию маршрута (в реальном приложении это должно приходить с бэкенда)
      final routePoints = [
        Point(latitude: currentLocation.lat, longitude: currentLocation.long),
        Point(latitude: place.latitude, longitude: place.longitude),
      ];

      // Обновляем маркер места назначения
      final destinationPlacemark = PlacemarkMapObject(
        mapId: MapObjectId('route_destination'),
        point: Point(latitude: place.latitude, longitude: place.longitude),
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image:
                BitmapDescriptor.fromAssetImage('assets/destination_pin.png'),
            scale: 0.5,
          ),
        ),
      );

      // Создаем полилинию маршрута
      final routePolyline = PolylineMapObject(
        mapId: MapObjectId('current_route'),
        polyline: Polyline(points: routePoints),
        strokeColor: Colors.blue.withOpacity(0.7),
        strokeWidth: 5,
      );

      // Обновляем состояние
      setState(() {
        _routePolyline = routePolyline;
        _destinationPlacemark = destinationPlacemark;
        _isRouteCalculating = false;
      });

      // Обновляем объекты карты
      _updateMapObjects();

      // Перемещаем камеру чтобы показать весь маршрут
      await _showRouteOnMap(routePoints);
    } catch (e) {
      setState(() => _isRouteCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка построения маршрута: ${e.toString()}')),
      );
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
      _mapObjects.removeWhere((obj) =>
          obj.mapId.value == 'current_route' ||
          obj.mapId.value == 'route_destination');

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

    // Центр маршрута
    final middleIndex = routePoints.length ~/ 2;
    final targetPoint = routePoints[middleIndex];

    await _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPoint,
          zoom: 15,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1,
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
      final location = await _locationService.getCurrentLocation();
      await _updateCamera(location.lat, location.long);
      _addUserPlacemark(location.lat, location.long);
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            mapObjects: _mapObjects,
            mapType: MapType.vector,
          ),
          if (_isLoading || _isRouteCalculating)
            const Center(child: CircularProgressIndicator()),
          // Панель информации о маршруте
          if (_routeDuration != null && _routeDistance != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Маршрут построен',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
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
