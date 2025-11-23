import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

/// Konum işlemlerini yöneten ViewModel
class LocationViewModel extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  // State variables
  LocationModel? _currentLocation;
  LocationServiceStatus _serviceStatus = const LocationServiceStatus(isEnabled: false, permissionStatus: LocationPermissionStatus.unknown);
  bool _isTracking = false;
  String? _errorMessage;

  // Stream subscriptions
  StreamSubscription<LocationModel>? _locationSubscription;
  StreamSubscription<LocationServiceStatus>? _statusSubscription;

  // Getters
  LocationModel? get currentLocation => _currentLocation;
  LocationServiceStatus get serviceStatus => _serviceStatus;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  bool get hasLocation => _currentLocation != null;
  bool get isLocationAvailable => _serviceStatus.isAvailable;
  LatLng? get currentPosition => _currentLocation?.position;
  double? get currentBearing => _currentLocation?.bearing;

  LocationViewModel() {
    _initializeLocationService();
  }

  /// Konum servisini başlat
  Future<void> _initializeLocationService() async {
    try {
      // Status stream'ini dinle
      _statusSubscription = _locationService.statusStream.listen(
        (status) {
          _serviceStatus = status;
          if (status.errorMessage != null) {
            _errorMessage = status.errorMessage;
          }
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Status stream hatası: $error');
          _errorMessage = 'Konum durumu dinleme hatası: $error';
          notifyListeners();
        },
      );

      // Location stream'ini dinle - Arkaplanda da çalışması için özel ayarlar
      _locationSubscription = _locationService.locationStream.listen(
        (location) {
          _currentLocation = location;
          _errorMessage = null; // Başarılı konum güncellemesinde hatayı temizle
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Location stream hatası: $error');
          _errorMessage = 'Konum alınamıyor: $error';
          notifyListeners();
        },
        cancelOnError: false, // Stream'i kapatma, hatanın ardından devam et
      );

      // İlk durum kontrolü
      await checkLocationServiceStatus();
    } catch (e) {
      _errorMessage = 'Konum servisi başlatılamadı: $e';
      notifyListeners();
    }
  }

  /// Konum servis durumunu kontrol et
  Future<void> checkLocationServiceStatus() async {
    try {
      _errorMessage = null;
      final status = await _locationService.checkLocationServiceStatus();
      _serviceStatus = status;

      if (status.errorMessage != null) {
        _errorMessage = status.errorMessage;
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Konum durumu kontrol edilemedi: $e';
      notifyListeners();
    }
  }

  /// Konum iznini iste
  Future<bool> requestLocationPermission() async {
    try {
      _errorMessage = null;
      final status = await _locationService.requestLocationPermission();
      _serviceStatus = status;

      if (status.errorMessage != null) {
        _errorMessage = status.errorMessage;
      }

      notifyListeners();
      return status.isAvailable;
    } catch (e) {
      _errorMessage = 'Konum izni istenemedi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mevcut konumu al
  Future<bool> getCurrentLocation() async {
    try {
      _errorMessage = null;
      final location = await _locationService.getCurrentLocation();

      if (location != null) {
        _currentLocation = location;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Konum alınamadı';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Konum alınamadı: $e';
      notifyListeners();
      return false;
    }
  }

  /// Konum takibini başlat
  Future<bool> startLocationTracking({LocationAccuracy accuracy = LocationAccuracy.high, int distanceFilter = 10}) async {
    try {
      _errorMessage = null;

      if (!_serviceStatus.isAvailable) {
        final permissionGranted = await requestLocationPermission();
        if (!permissionGranted) {
          _errorMessage = 'Konum izni gerekli';
          notifyListeners();
          return false;
        }
      }

      final success = await _locationService.startLocationTracking(accuracy: accuracy, distanceFilter: distanceFilter);

      if (success) {
        _isTracking = true;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Konum takibi başlatılamadı';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Konum takibi başlatılamadı: $e';
      notifyListeners();
      return false;
    }
  }

  /// Konum takibini durdur
  Future<void> stopLocationTracking() async {
    try {
      await _locationService.stopLocationTracking();
      _isTracking = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Konum takibi durdurulamadı: $e';
      notifyListeners();
    }
  }

  /// Konum ayarlarını aç
  Future<void> openLocationSettings() async {
    try {
      await _locationService.openLocationSettings();
    } catch (e) {
      _errorMessage = 'Konum ayarları açılamadı: $e';
      notifyListeners();
    }
  }

  /// Uygulama ayarlarını aç
  Future<void> openAppSettings() async {
    try {
      await _locationService.openAppSettings();
    } catch (e) {
      _errorMessage = 'Uygulama ayarları açılamadı: $e';
      notifyListeners();
    }
  }

  /// İki nokta arasındaki mesafeyi hesapla
  double calculateDistance(LatLng point1, LatLng point2) {
    return _locationService.calculateDistance(point1, point2);
  }

  /// İki nokta arasındaki yönü hesapla
  double calculateBearing(LatLng from, LatLng to) {
    return _locationService.calculateBearing(from, to);
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Konum verilerini sıfırla
  void resetLocation() {
    _currentLocation = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Konum servisini yeniden başlat
  Future<void> restartLocationService() async {
    await stopLocationTracking();
    await Future.delayed(const Duration(seconds: 1));
    await startLocationTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
