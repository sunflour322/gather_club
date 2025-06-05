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

  // Добавляем публичный метод для построения маршрута
  static void buildRouteToLocation(BuildContext context, double latitude,
      double longitude, String placeName) async {
    final state = globalKey.currentState;
    print('buildRouteToLocation: Вызван метод построения маршрута');
    print(
        'buildRouteToLocation: placeName = $placeName, lat = $latitude, long = $longitude');

    if (state != null && state.mounted) {
      print(
          'buildRouteToLocation: Состояние найдено, проверяем инициализацию карты');

      // Проверяем, инициализирован ли контроллер карты
      if (state._mapController == null) {
        print(
            'buildRouteToLocation: Контроллер карты не инициализирован, ожидаем инициализации');
        // Сохраняем координаты для последующего использования
        state._pendingLocation =
            Point(latitude: latitude, longitude: longitude);

        // Ждем инициализации карты
        int attempts = 0;
        const maxAttempts = 10;

        Future<void> waitForMapController() async {
          if (state._mapController != null || attempts >= maxAttempts) {
            if (state._mapController != null) {
              print(
                  'buildRouteToLocation: Контроллер карты инициализирован, продолжаем');
              // Повторно вызываем метод
              buildRouteToLocation(context, latitude, longitude, placeName);
            } else {
              print(
                  'buildRouteToLocation: Превышено максимальное количество попыток ожидания инициализации карты');
            }
            return;
          }

          attempts++;
          print(
              'buildRouteToLocation: Попытка $attempts ожидания инициализации карты');
          await Future.delayed(const Duration(milliseconds: 500));
          waitForMapController();
        }

        waitForMapController();
        return;
      }

      print(
          'buildRouteToLocation: Текущее местоположение пользователя: ${state.location}');

      // Создаем объект Place для построения маршрута
      final place = Place(
        placeId: 0, // Временный ID
        name: placeName,
        description: '',
        latitude: latitude,
        longitude: longitude,
        imageUrl: null,
        category: null,
        categoryId: null,
      );

      if (state.location != null) {
        print(
            'buildRouteToLocation: Местоположение пользователя доступно, создаем маршрут');
        print(
            'buildRouteToLocation: Создан объект Place, вызываем _buildRoute');
        // Вызываем метод построения маршрута
        state._buildRoute(place, {}, state.location!);
        print('buildRouteToLocation: Метод _buildRoute вызван');
      } else {
        print(
            'buildRouteToLocation: Местоположение пользователя недоступно, пытаемся получить его');
        try {
          // Получаем местоположение пользователя напрямую через LocationService
          final locationService = LocationService();
          final userLocation = await locationService.getCurrentLocation();

          print(
              'buildRouteToLocation: Местоположение получено напрямую: $userLocation');

          // Обновляем местоположение в state
          state.location = userLocation;

          // Добавляем метку пользователя на карту
          state._addUserPlacemark(userLocation.lat, userLocation.long);

          // Вызываем метод построения маршрута
          state._buildRoute(place, {}, userLocation);
          print(
              'buildRouteToLocation: Метод _buildRoute вызван с напрямую полученным местоположением');
        } catch (e) {
          print(
              'buildRouteToLocation: Ошибка при получении местоположения: $e');
          // Если не удалось получить местоположение, пробуем через _moveToCurrentLocation
          state._moveToCurrentLocation().then((_) {
            if (state.location != null) {
              print(
                  'buildRouteToLocation: Местоположение получено после _moveToCurrentLocation');
              // Вызываем метод построения маршрута
              state._buildRoute(place, {}, state.location!);
              print(
                  'buildRouteToLocation: Метод _buildRoute вызван после получения местоположения');
            } else {
              print(
                  'buildRouteToLocation: Не удалось получить местоположение пользователя');
            }
          });
        }
      }
    } else {
      print('buildRouteToLocation: Состояние не найдено или не активно');
      // Если состояние не найдено, пробуем найти его через контекст
      try {
        // Пытаемся найти состояние через контекст
        final navigatorState = Navigator.of(context);
        if (navigatorState.mounted) {
          // Переходим на страницу карты
          navigatorState.pushNamed('/map').then((_) {
            // После перехода на страницу карты пробуем снова построить маршрут
            Future.delayed(const Duration(milliseconds: 500), () {
              buildRouteToLocation(context, latitude, longitude, placeName);
            });
          });
        }
      } catch (e) {
        print('buildRouteToLocation: Ошибка при попытке перехода на карту: $e');
      }
    }
  }

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class PlaceCategory {
  final int id;
  final String name;
  final String? iconUrl;
  final bool isActive;
  bool isSelected;

  PlaceCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.isActive,
    this.isSelected = false,
  });

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['categoryId'],
      name: json['name'],
      iconUrl: json['iconUrl'],
      isActive: json['isActive'] ?? true,
      isSelected: false,
    );
  }

  // Создает иконку на основе URL или использует дефолтную
  IconData get icon {
    // Здесь можно добавить логику для маппинга URL на иконки
    // Пока используем дефолтные иконки
    switch (id) {
      case 0:
        return Icons.category;
      case 1:
        return Icons.local_cafe;
      case 2:
        return Icons.restaurant;
      case 3:
        return Icons.park;
      case 4:
        return Icons.museum;
      case 5:
        return Icons.movie;
      case 6:
        return Icons.sports_soccer;
      case 7:
        return Icons.shopping_bag;
      case 8:
        return Icons.hotel;
      default:
        return Icons.place;
    }
  }
}

class PlaceCategoryService {
  final AuthProvider _authProvider;
  final String _baseUrl = 'http://212.67.8.92:8080';

  PlaceCategoryService(this._authProvider);

  // Получение всех категорий мест
  Future<List<PlaceCategory>> getAllCategories() async {
    try {
      final token = await _authProvider.getToken();
      if (token == null) throw Exception('Не авторизован');

      print('Requesting categories from: $_baseUrl/place-categories');
      final response = await http.get(
        Uri.parse('$_baseUrl/place-categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Categories response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = json.decode(response.body);
        print(
            'Raw categories response: ${response.body.substring(0, min(200, response.body.length))}...');
        print('Parsed ${categoriesJson.length} categories from response');

        // Создаем категорию "Все" и добавляем ее в начало списка
        final List<PlaceCategory> categories = [
          PlaceCategory(
              id: 0,
              name: 'Все',
              iconUrl: null,
              isActive: true,
              isSelected: true)
        ];

        // Добавляем остальные категории из ответа сервера
        categories.addAll(categoriesJson
            .map((json) {
              print('Processing category: $json');
              return PlaceCategory.fromJson(json);
            })
            .where((category) => category.isActive) // Только активные категории
            .toList());

        print(
            'Final categories list: ${categories.map((c) => '${c.id}:${c.name}').join(', ')}');
        return categories;
      } else {
        print('Error response body: ${response.body}');
        throw Exception('Ошибка загрузки категорий: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching place categories: $e');
      // В случае ошибки возвращаем дефолтные категории
      return [
        PlaceCategory(
            id: 0,
            name: 'Все',
            iconUrl: null,
            isActive: true,
            isSelected: true),
        PlaceCategory(id: 1, name: 'Кафе', iconUrl: null, isActive: true),
        PlaceCategory(id: 2, name: 'Рестораны', iconUrl: null, isActive: true),
        PlaceCategory(id: 3, name: 'Парки', iconUrl: null, isActive: true),
      ];
    }
  }
}

class _ExamplePageState extends State<ExamplePage>
    with AutomaticKeepAliveClientMixin {
  final LocationService _locationService = LocationService();
  late UserLocationService _userLocationService;
  late PlaceCategoryService _categoryService;
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
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

  // Категории мест
  List<PlaceCategory> _categories = [
    PlaceCategory(
        id: 0, name: 'Все', iconUrl: null, isActive: true, isSelected: true),
  ];
  bool _isLoadingCategories = false;

  // Активные категории (для фильтрации)
  Set<int> _selectedCategoryIds = {0}; // По умолчанию выбрана категория "Все"

  // Все места, загруженные с сервера
  List<Place> _allPlaces = [];
  // Отфильтрованные места для отображения на карте
  List<Place> _places = [];
  bool _isLoadingPlaces = false;

  // Добавляем новые поля для поиска
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;
  List<Place> _searchResults = [];
  List<UserCustomPlace> _searchUserPlaces = [];
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userPlaceService = UserCustomPlaceService(authProvider);
    _userLocationService = UserLocationService(authProvider);
    _categoryService = PlaceCategoryService(authProvider);
    _initLocation();
    _fetchCategories();
    _fetchAllPlaces(); // Загружаем все места один раз
    _fetchUserPlaces();
    _startLocationUpdates();
    _friendsLocationUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_disposed) {
        _updateFriendsLocations();
      }
    });
    _searchController.addListener(_onSearchChanged);
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

  // Загрузка всех мест с сервера
  Future<void> _fetchAllPlaces() async {
    if (_disposed) return;

    _safeSetState(() => _isLoadingPlaces = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();
    print("token: $token");
    final location = await _locationService.getCurrentLocation();

    try {
      // Базовый URL для запроса всех мест без фильтрации по категориям
      String url =
          'http://212.67.8.92:8080/places/nearby?lat=${location.lat}&lng=${location.long}&radiusKm=10';

      print('Fetching all places with URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && !_disposed) {
        try {
          final List<dynamic> placesJson = json.decode(response.body);
          print('Received ${placesJson.length} places from server');

          // Вывод первого места для отладки
          if (placesJson.isNotEmpty) {
            print('First place sample: ${placesJson[0]}');
          }

          _safeSetState(() {
            _allPlaces =
                placesJson.map((json) => Place.fromJson(json)).toList();
            print('Loaded ${_allPlaces.length} places from server');

            // Применяем текущий фильтр категорий
            _filterPlacesByCategories();
          });
        } catch (parseError) {
          print('Error parsing places response: $parseError');
          print(
              'Response body: ${response.body.substring(0, min(200, response.body.length))}...');
        }
      } else {
        print('Failed to load places: ${response.statusCode}');
        print(
            'Response body: ${response.body.substring(0, min(200, response.body.length))}...');
      }
    } catch (e) {
      print('Error fetching places: $e');
    } finally {
      _safeSetState(() => _isLoadingPlaces = false);
    }
  }

  // Фильтрация мест по выбранным категориям (локально)
  void _filterPlacesByCategories() {
    if (_disposed) return;

    print('Filtering places by categories: $_selectedCategoryIds');
    print('Total places before filtering: ${_allPlaces.length}');

    // Вывод информации о всех местах для отладки
    for (var place in _allPlaces) {
      print(
          'Place ${place.placeId} (${place.name}): category=${place.category}, categoryId=${place.categoryId}');
    }

    // Сначала выполняем фильтрацию без setState
    List<Place> filteredPlaces;
    if (_selectedCategoryIds.contains(0)) {
      // Если выбрана категория "Все", показываем все места
      filteredPlaces = List.from(_allPlaces);
      print(
          'Showing all ${filteredPlaces.length} places (category "All" selected)');
    } else {
      // Фильтруем места по выбранным категориям
      filteredPlaces = _allPlaces.where((place) {
        // Проверяем, соответствует ли место хотя бы одной из выбранных категорий
        if (place.category == null) {
          print(
              'Place ${place.placeId} (${place.name}) has null category - skipping');
          return false;
        }

        // Получаем ID категории места
        int? placeCategoryId = place.categoryId;
        print(
            'Place ${place.placeId} (${place.name}): categoryId=${placeCategoryId}, category=${place.category}');

        // Проверяем по имени категории и ID
        for (var categoryId in _selectedCategoryIds) {
          var category = _categories.firstWhere((c) => c.id == categoryId,
              orElse: () => PlaceCategory(id: -1, name: '', isActive: false));

          // Проверка по ID категории
          if (placeCategoryId != null && placeCategoryId == categoryId) {
            print(
                'Place ${place.placeId} MATCHES by categoryId=${placeCategoryId} with selected categoryId=${categoryId}');
            return true;
          }

          // Проверка по имени категории
          if (category.id != -1 &&
              place.category!.toLowerCase() == category.name.toLowerCase()) {
            print(
                'Place ${place.placeId} MATCHES by category name: ${place.category} with selected category: ${category.name}');
            return true;
          }
        }

        print(
            'Place ${place.placeId} (${place.name}) does NOT match any selected category');
        return false;
      }).toList();

      print(
          'Filtered to ${filteredPlaces.length} places matching categories: ${_selectedCategoryIds.join(", ")}');
    }

    // Затем обновляем состояние и перерисовываем карту
    _safeSetState(() {
      _places = filteredPlaces;

      // Сначала удаляем все существующие метки мест
      _mapObjects.removeWhere((obj) =>
          obj.mapId.value.startsWith('place_') &&
          !obj.mapId.value.startsWith('place_user_'));
      print('Removed existing place markers from map');
    });

    // Добавляем новые метки мест после обновления состояния
    _addPlacesToMap();
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

      print('Adding ${_places.length} places to map');

      // Для отладки выведем категории мест
      if (_places.isNotEmpty) {
        print('Places categories:');
        for (final place in _places) {
          print(
              'Place ${place.placeId} (${place.name}): category=${place.category}, categoryId=${place.categoryId}');
        }
      }

      for (final place in _places) {
        if (_disposed) return;

        const thumbnailSize = 300;
        PlaceRepository placeRepository = PlaceRepository(_authProvider);
        List<PlaceImage> placeImages = [];

        try {
          placeImages = await placeRepository.fetchPlaceImages(place.placeId);
          print(
              'Fetched ${placeImages.length} images for place ${place.placeId} (${place.name})');
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
        _safeSetState(() {
          print('Adding ${placemarks.length} place markers to map');
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
    print('_requestPedestrianRoute: Начало запроса пешеходного маршрута');
    print(
        '_requestPedestrianRoute: Начальная точка - lat: ${startPoint.latitude}, long: ${startPoint.longitude}');
    print(
        '_requestPedestrianRoute: Конечная точка - lat: ${endPoint.latitude}, long: ${endPoint.longitude}');

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

    try {
      print('_requestPedestrianRoute: Вызываем YandexPedestrian.requestRoutes');
      // Дожидаемся выполнения и получаем кортеж
      final (session, resultFuture) = await YandexPedestrian.requestRoutes(
          points: points,
          // Новый формат параметров
          avoidSteep: true,
          timeOptions: TimeOptions() // Избегать крутых подъемов
          );

      print(
          '_requestPedestrianRoute: Получен сессионный объект, ожидаем результат');
      // Теперь ждем выполнения Future<PedestrianSessionResult>
      final result = await resultFuture;
      print('_requestPedestrianRoute: Получен результат маршрута');
      print(
          '_requestPedestrianRoute: Найдено маршрутов: ${result.routes?.length ?? 0}');

      return result;
    } catch (e) {
      print('_requestPedestrianRoute: Ошибка при запросе маршрута: $e');
      rethrow;
    }
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
      minLon = min(minLon, point.longitude);
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
      await _fetchAllPlaces();
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
    } else if (!_isLoading && location == null) {
      // Если карта уже загружена, но местоположение пользователя не определено,
      // попробуем получить его
      try {
        location = await _locationService.getCurrentLocation();
        _addUserPlacemark(location!.lat, location!.long);
        print(
            'Местоположение пользователя получено после создания карты: $location');
      } catch (e) {
        print('Ошибка при получении местоположения после создания карты: $e');
      }
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
    _searchController.dispose();
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
          // Слайдер категорий в верхней части экрана
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _buildCategoriesSlider(),
                // Добавляем поле поиска
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск мест...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearchActive
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Затемненный фон при активном поиске
          if (_isSearchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _searchController.clear();
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          // Результаты поиска
          if (_isSearchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Результаты поиска',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (_searchUserPlaces.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Мои места',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ..._searchUserPlaces.map((place) => _buildPlaceCard(
                                  name: place.name,
                                  description: place.description,
                                  onTap: () {
                                    _searchController.clear();
                                    _updateCamera(
                                        place.latitude, place.longitude);
                                  },
                                )),
                          ],
                          if (_searchResults.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Общие места',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ..._searchResults.map((place) => _buildPlaceCard(
                                  name: place.name,
                                  description: place.description,
                                  imageUrl: place.imageUrl,
                                  onTap: () {
                                    _searchController.clear();
                                    _updateCamera(
                                        place.latitude, place.longitude);
                                  },
                                )),
                          ],
                          if (_searchUserPlaces.isEmpty &&
                              _searchResults.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Ничего не найдено'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  // Обработка нажатия на категорию
  void _toggleCategory(int categoryId) {
    print(
        'Toggle category: $categoryId, current selected: $_selectedCategoryIds');

    // Сначала обновляем выбранные категории
    setState(() {
      // Если нажата категория "Все"
      if (categoryId == 0) {
        // Если "Все" уже выбрана, ничего не делаем
        if (_selectedCategoryIds.contains(0)) {
          print('Category "All" already selected, no changes');
          return;
        }
        // Иначе выбираем только "Все" и сбрасываем остальные
        _selectedCategoryIds.clear();
        _selectedCategoryIds.add(0);
        print('Selected "All" category, cleared other selections');

        // Обновляем состояние категорий
        for (var category in _categories) {
          category.isSelected = category.id == 0;
        }
      } else {
        // Если нажата любая другая категория

        // Если категория уже выбрана, снимаем выбор
        if (_selectedCategoryIds.contains(categoryId)) {
          _selectedCategoryIds.remove(categoryId);
          _categories.firstWhere((c) => c.id == categoryId).isSelected = false;
          print('Deselected category $categoryId');

          // Если не осталось выбранных категорий, выбираем "Все"
          if (_selectedCategoryIds.isEmpty) {
            _selectedCategoryIds.add(0);
            _categories.firstWhere((c) => c.id == 0).isSelected = true;
            print('No categories selected, defaulting to "All"');
          }
        } else {
          // Если категория не выбрана, добавляем её

          // Если была выбрана категория "Все", снимаем с неё выбор
          if (_selectedCategoryIds.contains(0)) {
            _selectedCategoryIds.remove(0);
            _categories.firstWhere((c) => c.id == 0).isSelected = false;
            print('Removed "All" category selection');
          }

          // Добавляем новую категорию
          _selectedCategoryIds.add(categoryId);
          _categories.firstWhere((c) => c.id == categoryId).isSelected = true;
          print('Selected category $categoryId');
        }
      }
    });

    print('Final selected categories: $_selectedCategoryIds');

    // Затем применяем фильтр категорий к уже загруженным местам
    // Вызываем вне setState для предотвращения вложенных setState
    _filterPlacesByCategories();
  }

  // Обновление отображения мест на карте в соответствии с выбранными категориями
  void _updatePlacesOnMap() {
    print(
        'Обновление мест на карте для категорий: ${_selectedCategoryIds.join(", ")}');

    // Применяем фильтр категорий к уже загруженным местам
    _filterPlacesByCategories();
  }

  // Виджет для отображения категорий в горизонтальном списке
  Widget _buildCategoriesSlider() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isLoadingCategories
          ? Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Загрузка категорий...'),
                  ],
                ),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _toggleCategory(category.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: category.isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: category.isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category.icon,
                            size: 18,
                            color: category.isSelected
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.name,
                            style: TextStyle(
                              color: category.isSelected
                                  ? Colors.white
                                  : Colors.grey[800],
                              fontWeight: category.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Загрузка категорий мест с сервера
  Future<void> _fetchCategories() async {
    if (_disposed) return;

    setState(() => _isLoadingCategories = true);

    try {
      print('Fetching place categories from server...');
      final categories = await _categoryService.getAllCategories();
      print('Received ${categories.length} categories from server');

      // Выводим полученные категории для отладки
      for (var category in categories) {
        print(
            'Category: id=${category.id}, name=${category.name}, isActive=${category.isActive}, isSelected=${category.isSelected}');
      }

      if (!_disposed) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;

          // Убедимся, что категория "Все" выбрана по умолчанию
          if (_categories.isNotEmpty && _categories[0].id == 0) {
            _categories[0].isSelected = true;
            _selectedCategoryIds = {0};
          }

          print('Categories loaded and set, selected: $_selectedCategoryIds');
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (!_disposed) {
        setState(() => _isLoadingCategories = false);

        // В случае ошибки устанавливаем базовые категории
        _categories = [
          PlaceCategory(
              id: 0,
              name: 'Все',
              iconUrl: null,
              isActive: true,
              isSelected: true),
          PlaceCategory(id: 1, name: 'Кафе', iconUrl: null, isActive: true),
          PlaceCategory(
              id: 2, name: 'Рестораны', iconUrl: null, isActive: true),
          PlaceCategory(id: 3, name: 'Парки', iconUrl: null, isActive: true),
        ];
        _selectedCategoryIds = {0};
        print('Set default categories due to error');
      }
    }
  }

  // Метод для обновления мест при изменении местоположения
  Future<void> _refreshPlaces() async {
    if (_disposed) return;
    await _fetchAllPlaces();
  }

  void _onSearchChanged() {
    if (_disposed) return;

    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _isSearchActive = _searchQuery.isNotEmpty;

      if (_isSearchActive) {
        // Фильтруем общие места
        _searchResults = _allPlaces.where((place) {
          final matchesSearch =
              place.name.toLowerCase().contains(_searchQuery) ||
                  (place.description?.toLowerCase().contains(_searchQuery) ??
                      false);

          // Проверяем соответствие категории
          final matchesCategory = _selectedCategoryIds.contains(0) ||
              _selectedCategoryIds.contains(place.categoryId);

          return matchesSearch && matchesCategory;
        }).toList();

        // Фильтруем пользовательские места
        _searchUserPlaces = _userPlaces.where((place) {
          return place.name.toLowerCase().contains(_searchQuery) ||
              (place.description?.toLowerCase().contains(_searchQuery) ??
                  false);
        }).toList();
      } else {
        _searchResults = [];
        _searchUserPlaces = [];
      }
    });
  }

  Widget _buildPlaceCard({
    required String name,
    String? description,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, size: 40),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
