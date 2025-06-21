import 'package:gather_club/api_services/place_serice/place.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class MapService {
  final YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];

  MapService(this._mapController);

  void addUserPlacemark(double lat, double long) {
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

    _mapObjects.removeWhere((obj) => obj.mapId.value == 'user_location');
    _mapObjects.add(placemark);
  }

  void addPlaces(List<Place> places) {
    final placemarks = places.map((place) {
      return PlacemarkMapObject(
        mapId: MapObjectId('place_${place.placeId}'),
        point: Point(latitude: place.latitude, longitude: place.longitude),
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('assets/logo.png'),
            scale: place.imageUrl != null ? 0.2 : 0.5,
          ),
        ),
        opacity: 1,
        onTap: (mapObject, point) => place,
      );
    }).toList();

    _mapObjects.addAll(placemarks);
  }

  Future<void> moveCamera(double lat, double long) async {
    await _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: lat, longitude: long),
          zoom: 15,
        ),
      ),
      animation: const MapAnimation(type: MapAnimationType.linear, duration: 1),
    );
  }

  List<MapObject> get mapObjects => _mapObjects;
}
