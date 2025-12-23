import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

      // Arka plan konumu için "always" izni iste
      if (permission == LocationPermission.whileInUse) {
        // Arka plan için always izni iste
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

  /// Arka plan konum iznini iste (Android için)
  Future<bool> requestBackgroundLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always) {
        return true;
      }

      if (permission == LocationPermission.whileInUse) {
        // Android için: Kullanıcıya arka plan izni iste
        final newPermission = await Geolocator.requestPermission();
        return newPermission == LocationPermission.always;
      }

      return false;
    } catch (e) {
      debugPrint('Arka plan konum izni hatası: $e');
      return false;
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

      final locationModel = LocationModel(position: LatLng(position.latitude, position.longitude), bearing: position.heading >= 0 ? position.heading : null, accuracy: position.accuracy, altitude: position.altitude, timestamp: DateTime.now());

      return locationModel;
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      return null;
    }
  }

  /// Konum takibini başlat - Canlı takip için optimize edildi
  Future<bool> startLocationTracking({LocationAccuracy accuracy = LocationAccuracy.bestForNavigation, int distanceFilter = 0}) async {
    try {
      final status = await checkLocationServiceStatus();
      if (!status.isAvailable) {
        return false;
      }

      // Mevcut stream'i kapat
      await stopLocationTracking();

      // Android için arka plan izni kontrolü
      await requestBackgroundLocationPermission();

      // Platform-specific location settings for continuous tracking
      late LocationSettings locationSettings;

      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter > 0 ? distanceFilter : 10, // Minimum 10m distance filter
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 1000), // Update every 1000ms (1 second)
          // Foreground Service bildirimi - Arka planda konum takibi için gerekli
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'Route tracking is active in background',
            notificationTitle: 'Trodden - Recording Route',
            notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWakeLock: true,
            enableWifiLock: true,
            setOngoing: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        // automotiveNavigation provides most frequent updates for real-time tracking
        locationSettings = AppleSettings(
          accuracy: accuracy,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: distanceFilter,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true, // iOS için arka plan güncellemeleri
        );
      } else {
        locationSettings = LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
      }

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          debugPrint('📍 YENİ KONUM ALINDI: ${position.latitude}, ${position.longitude}');
          debugPrint('📍 Altitude: ${position.altitude}, isMocked: ${position.isMocked}');
          final locationModel = LocationModel(position: LatLng(position.latitude, position.longitude), bearing: position.heading >= 0 ? position.heading : null, accuracy: position.accuracy, altitude: position.altitude, timestamp: DateTime.now());

          _locationController.add(locationModel);
          debugPrint('📍 LocationController\'a eklendi');
        },
        onError: (error) {
          debugPrint('❌ Konum stream hatası: $error');
          _statusController.add(LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.unknown, errorMessage: error.toString()));

          // Hata durumunda yeniden başlatmayı dene
          Future.delayed(const Duration(seconds: 3), () {
            if (_positionStream == null) {
              startLocationTracking(accuracy: accuracy, distanceFilter: distanceFilter);
            }
          });
        },
        cancelOnError: false,
      );

      debugPrint('✅ Konum takibi başlatıldı - distanceFilter: $distanceFilter, accuracy: $accuracy');
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

  /// Android pil optimizasyonunu hariç tutma isteği
  /// Bu, arka planda konum takibinin kesintisiz devam etmesini sağlar
  Future<bool> requestBatteryOptimizationExemption() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Diğer platformlarda gerekli değil
    }

    try {
      const platform = MethodChannel('app.trodden/battery');
      final result = await platform.invokeMethod<bool>('requestBatteryOptimizationExemption');
      debugPrint('🔋 Pil optimizasyonu hariç tutma isteği: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Pil optimizasyonu hariç tutma hatası: $e');
      // Method channel yoksa sessizce devam et
      return false;
    }
  }

  /// Servisi temizle
  void dispose() {
    stopLocationTracking();
    _locationController.close();
    _statusController.close();
  }
}
