import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/auth_service/auth_service.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:gather_club/place_serice/place.dart';
import 'package:gather_club/place_serice/place_image_service.dart';
import 'package:gather_club/widgets/place_info_dialog.dart';
import 'package:gather_club/place_serice/place_repository.dart';
import 'package:gather_club/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/user_custom_place_service.dart';
import '../place_serice/user_custom_place.dart';
import '../widgets/user_place_info_dialog.dart';
import 'package:gather_club/services/user_location_service.dart';
import 'package:gather_club/widgets/friend_info_dialog.dart';
import '../widgets/friend_info_overlay.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gather_club/widgets/custom_notification.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  static final GlobalKey<_ExamplePageState> globalKey =
      GlobalKey<_ExamplePageState>();

  static void navigateToLocation(
      BuildContext context, double latitude, double longitude) {
    final state = globalKey.currentState;
    if (state != null && state.mounted) {
      if (state._mapController != null) {
        // Если контроллер уже инициализирован, перемещаем камеру сразу
        state._updateCamera(latitude, longitude);
      } else {
        // Если контроллер еще не инициализирован, сохраняем координаты
        state._pendingLocation =
            Point(latitude: latitude, longitude: longitude);
      }
    }
  }

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage>
    with AutomaticKeepAliveClientMixin {
  final LocationService _locationService = LocationService();
  late UserLocationService _userLocationService;
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  List<Place> _places = [];
  AuthService _authService = AuthService();
  PolylineMapObject? _routePolyline;
  String? _routeDuration;
  String? _routeDistance;
  String? _destinationName;
  bool _isRouteCalculating = false;
  AppLatLong? location;
  Point? _lastCameraPosition;
  PlacemarkMapObject? _tempPlacemark;
  Point? _pendingLocation;
  TextEditingController _placeNameController = TextEditingController();
  late UserCustomPlaceService _userPlaceService;
  List<UserCustomPlace> _userPlaces = [];
  Timer? _locationUpdateTimer;
  Timer? _friendsLocationUpdateTimer;
  bool _disposed = false;
  UserLocation? _selectedFriend;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userPlaceService = UserCustomPlaceService(authProvider);
    _userLocationService = UserLocationService(authProvider);
    _initLocation();
    _fetchPlaces();
    _fetchUserPlaces();
    _startLocationUpdates();
    _friendsLocationUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_disposed) {
        _updateFriendsLocations();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем места при возвращении на экран
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserPlaces();
    });
  }

  void _saveCameraPosition() {
    _mapController?.getCameraPosition().then((position) {
      _lastCameraPosition = position.target;
    });
  }

// Восстанавливаем позицию при возврате
  void _restoreCameraPosition() {
    if (_lastCameraPosition != null) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _lastCameraPosition!, zoom: 15),
        ),
      );
    }
  }

  // Безопасный setState
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      setState(fn);
    }
  }

  Future<void> _fetchPlaces() async {
    if (_disposed) return;

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

      if (response.statusCode == 200 && !_disposed) {
        final List<dynamic> placesJson = json.decode(response.body);
        _safeSetState(() {
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

  Future<void> _fetchUserPlaces() async {
    if (_disposed) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = await authProvider.getUserId();
      final places = await _userPlaceService.getAllPlaces(userId);

      if (!_disposed) {
        _safeSetState(() {
          _userPlaces = places;
          _addUserPlacesToMap();
        });
      }
    } catch (e) {
      print('Error fetching user places: $e');
    }
  }

  Future<void> _addPlacesToMap() async {
    if (_disposed) return;

    try {
      final placemarks = <PlacemarkMapObject>[];
      final _authProvider = Provider.of<AuthProvider>(context, listen: false);

      for (final place in _places) {
        if (_disposed) return;

        const thumbnailSize = 300;
        PlaceRepository placeRepository = PlaceRepository(_authProvider);
        List<PlaceImage> placeImages = [];

        try {
          placeImages = await placeRepository.fetchPlaceImages(place.placeId);
        } catch (e) {
          print('Error fetching images for place ${place.placeId}: $e');
          continue;
        }

        if (_disposed) return;

        final Uint8List? thumbnailBytes = place.imageUrl != null
            ? await _createSquareThumbnail(place.imageUrl!, thumbnailSize)
            : null;

        if (_disposed) return;

        placemarks.add(PlacemarkMapObject(
          mapId: MapObjectId('place_${place.placeId}'),
          point: Point(latitude: place.latitude, longitude: place.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: thumbnailBytes != null
                  ? BitmapDescriptor.fromBytes(thumbnailBytes)
                  : BitmapDescriptor.fromAssetImage(
                      'assets/default_avatar.png'),
              scale: thumbnailBytes != null ? 0.3 : 0.2,
            ),
          ),
          opacity: 1,
          onTap: (mapObject, point) {
            if (!_disposed) {
              _showPlaceInfo(place, placeImages, location!);
            }
          },
        ));
      }

      if (!_disposed) {
        setState(() {
          _mapObjects.addAll(placemarks);
        });
      }
    } catch (e) {
      print('Error in _addPlacesToMap: $e');
    }
  }

  void _addUserPlacesToMap() {
    if (_disposed) return;

    try {
      final placemarks = _userPlaces.map((place) {
        return PlacemarkMapObject(
          opacity: 1,
          mapId: MapObjectId('user_place_${place.placeId}'),
          point: Point(latitude: place.latitude, longitude: place.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/pin.png'),
              scale: 0.2,
            ),
          ),
          onTap: (_, __) => _showUserPlaceInfo(place),
        );
      }).toList();

      setState(() {
        _mapObjects
            .removeWhere((obj) => obj.mapId.value.startsWith('user_place_'));
        _mapObjects.addAll(placemarks);
      });
    } catch (e) {
      print('Error in _addUserPlacesToMap: $e');
    }
  }

  Future<Uint8List?> _createRoundedThumbnail(String imageUrl, int size) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      var image = frame.image;

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

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final padding = size * 0.1;
      final totalSize = size + (padding * 2);

      final path = Path()
        ..addOval(
            Rect.fromLTWH(padding, padding, size.toDouble(), size.toDouble()));

      canvas.drawShadow(path, Colors.black, 8.0, true);
      canvas.clipPath(path);

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(padding, padding, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = ui.FilterQuality.high,
      );

      // Добавляем красную обводку
      final borderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(
        Offset(padding + size / 2, padding + size / 2),
        size / 2,
        borderPaint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(totalSize.toInt(), totalSize.toInt());
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

  Future<Uint8List?> _createSquareThumbnail(String imageUrl, int size) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      var image = frame.image;

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

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final padding = size * 0.1;
      final totalSize = size + (padding * 2);
      final radius = size * 0.2; // Радиус закругления углов

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, padding, size.toDouble(), size.toDouble()),
        Radius.circular(radius),
      );
      final path = Path()..addRRect(rrect);

      canvas.drawShadow(path, Colors.black, 8.0, true);
      canvas.clipPath(path);

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(padding, padding, size.toDouble(), size.toDouble()),
        Paint()..filterQuality = ui.FilterQuality.high,
      );

      // Добавляем белую обводку
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRRect(rrect, borderPaint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error creating square thumbnail: $e');
      return null;
    }
  }

  void _showPlaceInfo(
      Place place, List<PlaceImage> placeImages, AppLatLong location) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final imageService = PlaceImageService(authProvider);
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
        imageService: imageService,
      ),
    );
  }

  void _showUserPlaceInfo(UserCustomPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserPlaceInfoDialog(
        place: place,
        onRouteBuilt: (place) {
          if (location != null) {
            _buildRoute(
              Place(
                placeId: place.placeId,
                name: place.name,
                description: place.description,
                latitude: place.latitude,
                longitude: place.longitude,
                imageUrl: place.imageUrl,
              ),
              {},
              location!,
            );
          }
          Navigator.pop(context);
        },
        onRouteCleared: _clearRoute,
        onDelete: () async {
          try {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            final userId = await authProvider.getUserId();
            await _userPlaceService.deletePlace(userId, place.placeId);
            await _fetchUserPlaces();
            CustomNotification.show(context, 'Метка удалена');
          } catch (e) {
            CustomNotification.show(context, 'Ошибка при удалении метки: $e');
          }
        },
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
    setState(() {
      _isRouteCalculating = true;
      _destinationName = place.name;
    });

    try {
      final startPoint =
          Point(latitude: location.lat, longitude: location.long);
      final endPoint =
          Point(latitude: place.latitude, longitude: place.longitude);

      final result = await _requestPedestrianRoute(startPoint, endPoint);

      if (result.routes != null && result.routes!.isNotEmpty) {
        final route = result.routes!.first;

        final timeText = route.metadata.weight.time.text;
        final distanceText = route.metadata.weight.walkingDistance.text;

        setState(() {
          _routeDuration = timeText;
          _routeDistance = distanceText;
        });

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

        setState(() {
          _routePolyline = routePolyline;
        });

        _updateMapObjects();
        await _showRouteOnMap(route.geometry.points);
      } else {
        throw Exception('Не удалось построить пешеходный маршрут');
      }
    } catch (e) {
      CustomNotification.show(
          context, 'Ошибка построения пешеходного маршрута: ${e.toString()}');
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
    if (_disposed) return;

    _safeSetState(() {
      _routePolyline = null;
      _routeDuration = null;
      _routeDistance = null;
      _destinationName = null;
    });
    _updateMapObjects();
  }

  void _updateMapObjects() {
    if (_disposed) return;

    _safeSetState(() {
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'current_route');

      if (_routePolyline != null) {
        _mapObjects.add(_routePolyline!);
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

    await _mapController?.moveCamera(
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
    if (_disposed) return;

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

    if (!_disposed) {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_disposed) return;

    try {
      location = await _locationService.getCurrentLocation();
      await _updateCamera(location!.lat, location!.long);
      _addUserPlacemark(location!.lat, location!.long);
      await _fetchPlaces();
    } catch (e) {
      print('Error moving to current location: $e');
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
    print('Updating camera to: $lat, $long');
    if (_mapController != null) {
      try {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: Point(latitude: lat, longitude: long),
              zoom: 15,
            ),
          ),
          animation:
              const MapAnimation(type: MapAnimationType.linear, duration: 1),
        );
        print('Camera updated successfully');
      } catch (e) {
        print('Error updating camera: $e');
      }
    } else {
      print('Map controller is null');
    }
  }

  void _addUserPlacemark(double lat, double long) {
    if (_disposed) return;

    final placemark = PlacemarkMapObject(
      opacity: 1,
      mapId: const MapObjectId('user_location'),
      point: Point(latitude: lat, longitude: long),
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/location.png'),
          scale: 0.2,
        ),
      ),
    );

    _safeSetState(() {
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'user_location');
      _mapObjects.add(placemark);
    });
  }

  void _handleMapLongPress(Point point) async {
    // Сохраняем текущую позицию камеры
    final currentPosition = await _mapController?.getCameraPosition();
    final currentZoom = currentPosition?.zoom ??
        15.0; // Используем значение по умолчанию, если zoom не определен

    // Создаем временную метку
    final tempPlacemark = PlacemarkMapObject(
      mapId: const MapObjectId('temp_placemark'),
      point: point,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/pin.png'),
          scale: 0.2,
          anchor: const Offset(0.5, 1.0),
        ),
      ),
      opacity: 1.0,
    );

    setState(() {
      _mapObjects.removeWhere((obj) => obj.mapId.value == 'temp_placemark');
      _mapObjects.add(tempPlacemark);
      _tempPlacemark = tempPlacemark;
    });

    await _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: currentZoom,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.5,
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (location != null) {
                          _buildRoute(
                            Place(
                              placeId: 0,
                              name: _placeNameController.text.isEmpty
                                  ? 'Новое место'
                                  : _placeNameController.text,
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
                      icon: const Icon(Icons.directions_walk, size: 20),
                      label: const Text('Маршрут'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          final userId = await authProvider.getUserId();
                          print('Creating place for userId: $userId');

                          if (userId <= 0) {
                            throw Exception('Invalid userId: $userId');
                          }

                          final place = UserCustomPlace(
                            placeId: 0,
                            userId: userId,
                            name: _placeNameController.text.isEmpty
                                ? 'Новое место'
                                : _placeNameController.text,
                            description: '',
                            latitude: point.latitude,
                            longitude: point.longitude,
                            categoryId: 1,
                            imageUrl: null,
                          );
                          await _userPlaceService.createPlace(userId, place);
                          await _fetchUserPlaces();
                          Navigator.pop(context);
                          CustomNotification.show(context, 'Место сохранено');
                        } catch (e) {
                          print('Error creating place: $e');
                          CustomNotification.show(
                              context, 'Ошибка при сохранении: $e');
                        }
                      },
                      icon: const Icon(Icons.save, size: 20),
                      label: const Text('Сохранить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final place = {
                          'name': _placeNameController.text.isEmpty
                              ? 'Новое место'
                              : _placeNameController.text,
                          'latitude': point.latitude,
                          'longitude': point.longitude,
                        };
                        Navigator.pushNamed(
                          context,
                          '/create_meetup',
                          arguments: place,
                        );
                      },
                      icon: const Icon(Icons.group_add, size: 20),
                      label: const Text('Встреча'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        if (_tempPlacemark != null) {
          _mapObjects.removeWhere((obj) => obj.mapId.value == 'temp_placemark');
          _tempPlacemark = null;
        }
        _placeNameController.clear();
      });
    });
  }

  void _onMapCreated(YandexMapController controller) async {
    print('Map created');
    _mapController = controller;

    if (_isLoading && _hasLocationPermission) {
      await _moveToCurrentLocation();
    }

    if (_pendingLocation != null) {
      print(
          'Moving to pending location: ${_pendingLocation!.latitude}, ${_pendingLocation!.longitude}');
      await _updateCamera(
          _pendingLocation!.latitude, _pendingLocation!.longitude);
      _pendingLocation = null;
    }

    // Загружаем данные о друзьях сразу при создании карты
    _updateFriendsLocations();
  }

  void _startLocationUpdates() {
    _locationUpdateTimer =
        Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!_disposed && location != null) {
        try {
          final userId = await Provider.of<AuthProvider>(context, listen: false)
              .getUserId();
          await _userLocationService.updateLocation(
            userId,
            UserLocation(
              userId: userId,
              latitude: location!.lat,
              longitude: location!.long,
              timestamp: DateTime.now(),
              isPublic: true,
            ),
          );
        } catch (e) {
          print('Error updating location: $e');
        }
      }
    });
  }

  void _startFriendsLocationUpdates() {
    _friendsLocationUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_disposed) {
        _updateFriendsLocations();
      }
    });
  }

  Future<void> _updateFriendsLocations() async {
    try {
      print('Starting friends locations update...');
      final friendsLocations = await _userLocationService.getFriendsLocations();
      print('Received ${friendsLocations.length} friend locations');

      // Фильтруем локации, чтобы исключить некорректные данные
      final validLocations = friendsLocations.where((location) {
        final isValid = location.latitude != 0 &&
            location.longitude != 0 &&
            location.userId > 0;
        if (!isValid) {
          print(
              'Skipping invalid location for user ${location.userId}: lat=${location.latitude}, lon=${location.longitude}');
        }
        return isValid;
      }).toList();

      print('Valid locations count: ${validLocations.length}');

      for (var location in validLocations) {
        print('Friend location details:');
        print('- UserId: ${location.userId}');
        print('- Username: ${location.userName ?? "Unknown"}');
        print('- Coordinates: ${location.latitude}, ${location.longitude}');
        print('- Avatar URL: ${location.userAvatar ?? "No avatar"}');
        print('- Timestamp: ${location.timestamp}');
      }

      if (_disposed) {
        print('Widget is disposed, stopping update');
        return;
      }

      setState(() {
        // Подсчитываем количество меток друзей до удаления
        final beforeCount = _mapObjects
            .where((obj) => obj.mapId.value.startsWith('friend_'))
            .length;
        print('Friend markers before removal: $beforeCount');

        // Удаляем старые метки друзей
        _mapObjects.removeWhere((obj) => obj.mapId.value.startsWith('friend_'));
        print('Removed old friend markers');

        // Добавляем новые метки друзей
        for (final friendLocation in validLocations) {
          print(
              'Adding marker for friend ${friendLocation.userId} at ${friendLocation.latitude}, ${friendLocation.longitude}');
          _addFriendPlacemark(friendLocation);
        }

        // Подсчитываем количество меток после добавления
        final afterCount = _mapObjects
            .where((obj) => obj.mapId.value.startsWith('friend_'))
            .length;
        print('Friend markers after update: $afterCount');
      });
    } catch (e, stackTrace) {
      print('Error updating friends locations: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _addFriendPlacemark(UserLocation friendLocation,
      {bool startAnimation = true}) async {
    try {
      print('Starting to create placemark for friend ${friendLocation.userId}');

      Uint8List? avatarBytes;
      if (friendLocation.userAvatar != null) {
        try {
          avatarBytes =
              await _createRoundedThumbnail(friendLocation.userAvatar!, 200);
        } catch (e) {
          print('Error processing avatar: $e');
        }
      }

      if (_disposed) {
        return;
      }

      print('Creating friend placemark object');
      final friendPlacemark = PlacemarkMapObject(
        mapId: MapObjectId('friend_${friendLocation.userId}'),
        point: Point(
            latitude: friendLocation.latitude,
            longitude: friendLocation.longitude),
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: avatarBytes != null
                ? BitmapDescriptor.fromBytes(avatarBytes)
                : BitmapDescriptor.fromAssetImage('assets/default_avatar.png'),
            scale: avatarBytes != null ? 0.8 : 0.3,
          ),
        ),
        opacity: 1.0,
        onTap: (_, __) => _showFriendInfo(friendLocation),
      );

      setState(() {
        print('Adding friend placemark to map objects');
        _mapObjects.removeWhere(
            (obj) => obj.mapId.value == 'friend_${friendLocation.userId}');
        _mapObjects.add(friendPlacemark);
        print('Friend placemark added successfully');
      });
    } catch (e, stackTrace) {
      print('Error adding friend placemark: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _showFriendInfo(UserLocation friendLocation) {
    setState(() {
      _selectedFriend = friendLocation;
    });
  }

  void _hideFriendInfo() {
    setState(() {
      _selectedFriend = null;
    });
  }

  @override
  void dispose() {
    print('Disposing ExamplePage');
    _disposed = true;
    _locationUpdateTimer?.cancel();
    _friendsLocationUpdateTimer?.cancel();
    _placeNameController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    print('Deactivating ExamplePage');
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      key: ExamplePage.globalKey,
      body: Stack(
        children: [
          YandexMap(
            nightModeEnabled: false,
            onMapCreated: _onMapCreated,
            onMapLongTap: (Point point) {
              _handleMapLongPress(point);
            },
            mapObjects: _mapObjects,
            mapType: MapType.vector,
            poiLimit: 0,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_walk,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationName ?? 'Пешеходный маршрут',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedFriend != null)
            FriendInfoOverlay(
              friendLocation: _selectedFriend!,
              onRouteBuilt: () {
                if (location != null) {
                  _buildRoute(
                    Place(
                      placeId: _selectedFriend!.userId,
                      name: _selectedFriend!.userName ?? 'Друг',
                      description: null,
                      latitude: _selectedFriend!.latitude,
                      longitude: _selectedFriend!.longitude,
                      imageUrl: _selectedFriend!.userAvatar,
                    ),
                    {},
                    location!,
                  );
                }
              },
              onRouteCleared: _clearRoute,
              onChat: () {
                Navigator.pushNamed(context, '/chat',
                    arguments: _selectedFriend!.userId);
              },
              onClose: _hideFriendInfo,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'location',
        onPressed: _hasLocationPermission ? _moveToCurrentLocation : null,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
