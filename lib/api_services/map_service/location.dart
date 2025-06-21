import 'package:geolocator/geolocator.dart';

class AppLatLong {
  final double lat;
  final double long;

  const AppLatLong({
    required this.lat,
    required this.long,
  });
}

class MoscowLocation extends AppLatLong {
  const MoscowLocation({
    super.lat = 55.7887,
    super.long = 49.1221,
  });
}

abstract class AppLocation {
  Future<AppLatLong> getCurrentLocation();
  Future<LocationPermission> requestPermission();
  Future<LocationPermission> checkPermission();
}

class LocationService implements AppLocation {
  final defLocation = const MoscowLocation();

  @override
  Future<AppLatLong> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      return AppLatLong(lat: position.latitude, long: position.longitude);
    } catch (e) {
      return defLocation;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Дополнительный метод для удобной проверки разрешений
  Future<bool> hasLocationPermission() async {
    final status = await checkPermission();
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }
}
