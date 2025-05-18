import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gather_club/auth_service/auth_provider.dart';
import 'package:gather_club/map_service/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

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

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Проверяем и запрашиваем разрешения
    _hasLocationPermission = await _locationService.hasLocationPermission();
    if (!_hasLocationPermission) {
      final permission = await _locationService.requestPermission();
      _hasLocationPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    }

    if (_hasLocationPermission) {
      await _moveToCurrentLocation();
    } else {
      // Если разрешения нет, показываем Москву по умолчанию
      await _moveToDefaultLocation();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      await _updateCamera(location.lat, location.long);
      _addUserPlacemark(location.lat, location.long);
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
      _mapObjects.clear();
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
        title: const Text('Яндекс Карты'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _hasLocationPermission ? _moveToCurrentLocation : null,
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
      floatingActionButton: FloatingActionButton(
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
    );
  }
}
