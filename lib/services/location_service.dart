import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';

/// Konum işlemlerini yöneten servis sınıfı
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  final StreamController<LocationModel> _locationController = StreamController<LocationModel>.broadcast();
  final StreamController<LocationServiceStatus> _statusController = StreamController<LocationServiceStatus>.broadcast();

  /// Konum güncellemelerini dinlemek için stream
  Stream<LocationModel> get locationStream => _locationController.stream;

  /// Konum servisi durumunu dinlemek için stream
  Stream<LocationServiceStatus> get statusStream => _statusController.stream;

  /// Konum servisinin durumunu kontrol et
  Future<LocationServiceStatus> checkLocationServiceStatus() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final LocationPermission permission = await Geolocator.checkPermission();

      final LocationPermissionStatus permissionStatus = _mapPermission(permission);

      final status = LocationServiceStatus(isEnabled: serviceEnabled, permissionStatus: permissionStatus);

      _statusController.add(status);
      return status;
    } catch (e) {
      final status = LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.unknown, errorMessage: e.toString());
      _statusController.add(status);
      return status;
    }
  }

  /// Konum iznini iste
  Future<LocationServiceStatus> requestLocationPermission() async {
    try {
      // Önce servisin açık olup olmadığını kontrol et
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final status = LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.denied, errorMessage: 'Konum servisi kapalı');
        _statusController.add(status);
        return status;
      }

      // İzin durumunu kontrol et
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final LocationPermissionStatus permissionStatus = _mapPermission(permission);

      final status = LocationServiceStatus(isEnabled: serviceEnabled, permissionStatus: permissionStatus);

      _statusController.add(status);
      return status;
    } catch (e) {
      final status = LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.unknown, errorMessage: e.toString());
      _statusController.add(status);
      return status;
    }
  }

  /// Mevcut konumu al
  Future<LocationModel?> getCurrentLocation() async {
    try {
      final status = await checkLocationServiceStatus();
      if (!status.isAvailable) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );

      final locationModel = LocationModel(position: LatLng(position.latitude, position.longitude), bearing: position.heading >= 0 ? position.heading : null, accuracy: position.accuracy, timestamp: DateTime.now());

      return locationModel;
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      return null;
    }
  }

  /// Konum takibini başlat
  Future<bool> startLocationTracking({LocationAccuracy accuracy = LocationAccuracy.high, int distanceFilter = 10}) async {
    try {
      final status = await checkLocationServiceStatus();
      if (!status.isAvailable) {
        return false;
      }

      // Mevcut stream'i kapat
      await stopLocationTracking();

      // Android için foreground notification ayarla (arkaplanda konum almak için)
      await Geolocator.requestPermission();

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: accuracy,
              distanceFilter: distanceFilter,
              timeLimit: const Duration(seconds: 60), // Timeout süresini 60 saniyeye artırdık
            ),
          ).listen(
            (Position position) {
              final locationModel = LocationModel(position: LatLng(position.latitude, position.longitude), bearing: position.heading >= 0 ? position.heading : null, accuracy: position.accuracy, timestamp: DateTime.now());

              _locationController.add(locationModel);
            },
            onError: (error) {
              debugPrint('Konum stream hatası: $error');
              _statusController.add(LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.unknown, errorMessage: error.toString()));

              // Hata durumunda yeniden başlatmayı dene
              Future.delayed(const Duration(seconds: 5), () {
                startLocationTracking(accuracy: accuracy, distanceFilter: distanceFilter);
              });
            },
            cancelOnError: false,
          );

      return true;
    } catch (e) {
      debugPrint('Konum takibi başlatılamadı: $e');
      return false;
    }
  }

  /// Konum takibini durdur
  Future<void> stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  /// Konum ayarlarını aç
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Uygulama ayarlarını aç
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// İki nokta arasındaki mesafeyi hesapla
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  /// İki nokta arasındaki yönü hesapla
  double calculateBearing(LatLng from, LatLng to) {
    final double lat1Rad = from.latitude * (math.pi / 180);
    final double lat2Rad = to.latitude * (math.pi / 180);
    final double deltaLngRad = (to.longitude - from.longitude) * (math.pi / 180);

    final double y = math.sin(deltaLngRad) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) - math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLngRad);

    final double bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  /// LocationPermission'ı LocationPermissionStatus'a dönüştür
  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Servisi temizle
  void dispose() {
    stopLocationTracking();
    _locationController.close();
    _statusController.close();
  }
}
