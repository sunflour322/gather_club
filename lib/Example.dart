import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/auth_service/auth_service.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Place {
  final int placeId;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  Place({
    required this.placeId,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      placeId: json['placeId'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      imageUrl: json['imageUrl'],
    );
  }
}

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

    try {
      final response = await http.get(
        Uri.parse(
            'http://212.67.8.92:8080/places/nearby?lat=55.751244&lng=49.145908&radiusKm=10'),
        headers: {
          'Authorization':
              'Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIzIiwiaWF0IjoxNzQ3NjE3ODY3LCJleHAiOjE3NDc3MDQyNjd9.bw5GZXs2HcvxeH-Rgan74NS9T_r8Ub2jcPnC0Sz0mbrfXlLxZVykvUA582kfp6uMOooQaRCTKP3H0UVg0_Fn1w',
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

  void _addPlacesToMap() {
    final placemarks = _places.map((place) {
      return PlacemarkMapObject(
        mapId: MapObjectId('place_${place.placeId}'),
        point: Point(latitude: place.latitude, longitude: place.longitude),
        icon: place.imageUrl != null
            ? PlacemarkIcon.single(
                PlacemarkIconStyle(
                  image: BitmapDescriptor.fromAssetImage('assets/logo.png'),
                  scale: 0.2,
                ),
              )
            : PlacemarkIcon.single(
                PlacemarkIconStyle(
                  image: BitmapDescriptor.fromAssetImage('assets/logo.png'),
                  scale: 0.5,
                ),
              ),
        opacity: 1,
        onTap: (mapObject, point) {
          _showPlaceInfo(place);
        },
      );
    }).toList();

    setState(() {
      _mapObjects.addAll(placemarks);
    });
  }

  void _showPlaceInfo(Place place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.description != null) Text(place.description!),
            const SizedBox(height: 10),
            if (place.imageUrl != null)
              Image.network(
                place.imageUrl!,
                height: 50,
                width: 50,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
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
      mapId: const MapObjectId('user_location'),
      point: Point(latitude: lat, longitude: long),
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/logo.png'),
          scale: 0.1,
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
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
