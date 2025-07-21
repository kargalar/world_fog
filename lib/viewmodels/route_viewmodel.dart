import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';

/// Rota işlemlerini yöneten ViewModel
class RouteViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  // Current route state
  RouteModel? _currentRoute;
  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _routeStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPausedTime = Duration.zero;
  Duration _currentBreakDuration = Duration.zero;

  // Route data
  final List<RoutePoint> _currentRoutePoints = [];
  final List<LatLng> _currentRouteExploredAreas = [];
  double _currentRouteDistance = 0.0;
  Duration _currentRouteDuration = Duration.zero;

  // Timers
  Timer? _durationTimer;
  Timer? _breakTimer;

  // Past routes
  List<RouteModel> _pastRoutes = [];
  bool _isLoadingRoutes = false;
  String? _errorMessage;

  // Getters - Current route
  RouteModel? get currentRoute => _currentRoute;
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  bool get isActive => _isTracking && !_isPaused;
  DateTime? get routeStartTime => _routeStartTime;
  Duration get totalPausedTime => _totalPausedTime;
  Duration get currentBreakDuration => _currentBreakDuration;

  // Getters - Route data
  List<RoutePoint> get currentRoutePoints => List.unmodifiable(_currentRoutePoints);
  List<LatLng> get currentRouteExploredAreas => List.unmodifiable(_currentRouteExploredAreas);
  double get currentRouteDistance => _currentRouteDistance;
  Duration get currentRouteDuration => _currentRouteDuration;
  int get currentRoutePointsCount => _currentRoutePoints.length;

  // Getters - Past routes
  List<RouteModel> get pastRoutes => List.unmodifiable(_pastRoutes);
  bool get isLoadingRoutes => _isLoadingRoutes;
  String? get errorMessage => _errorMessage;
  int get pastRoutesCount => _pastRoutes.length;

  RouteViewModel() {
    _initializeRoutes();
  }

  /// Rotaları başlat
  Future<void> _initializeRoutes() async {
    await loadPastRoutes();
  }

  /// Rota takibini başlat
  void startTracking(LatLng? initialPosition) {
    if (_isTracking) return;

    _isTracking = true;
    _isPaused = false;
    _routeStartTime = DateTime.now();
    _currentRouteDistance = 0.0;
    _currentRouteDuration = Duration.zero;
    _totalPausedTime = Duration.zero;
    _currentBreakDuration = Duration.zero;
    _currentRoutePoints.clear();
    _currentRouteExploredAreas.clear();

    // Başlangıç noktasını ekle
    if (initialPosition != null) {
      _currentRoutePoints.add(RoutePoint(position: initialPosition, altitude: 0.0, timestamp: DateTime.now()));
    }

    // Süre sayacını başlat
    _startDurationTimer();

    _errorMessage = null;
    notifyListeners();
  }

  /// Rota takibini duraklat
  void pauseTracking() {
    if (!_isTracking || _isPaused) return;

    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _currentBreakDuration = Duration.zero;

    // Mola sayacını başlat
    _startBreakTimer();

    notifyListeners();
  }

  /// Rota takibini devam ettir
  void resumeTracking() {
    if (!_isTracking || !_isPaused) return;

    _isPaused = false;

    // Toplam mola süresini güncelle
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPausedTime += pauseDuration;
    }

    _pauseStartTime = null;
    _currentBreakDuration = Duration.zero;

    // Mola sayacını durdur
    _breakTimer?.cancel();

    notifyListeners();
  }

  /// Rota takibini durdur ve kaydet
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    // Timers'ı durdur
    _durationTimer?.cancel();
    _breakTimer?.cancel();

    // Son mola süresini hesapla
    if (_isPaused && _pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPausedTime += pauseDuration;
    }

    // Rota modelini oluştur
    if (_routeStartTime != null && _currentRoutePoints.isNotEmpty) {
      final route = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Rota ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        routePoints: List.from(_currentRoutePoints),
        exploredAreas: List.from(_currentRouteExploredAreas),
        totalDistance: _currentRouteDistance,
        totalDuration: _currentRouteDuration,
        totalBreakTime: _totalPausedTime,
        startTime: _routeStartTime!,
        endTime: DateTime.now(),
      );

      // Rotayı kaydet
      await saveRoute(route);
    }

    // State'i sıfırla
    _resetRouteState();
    notifyListeners();
  }

  /// Yeni konum noktası ekle
  void addLocationPoint(LocationModel location) {
    if (!_isTracking || _isPaused) return;

    // Mesafe hesapla
    if (_currentRoutePoints.isNotEmpty) {
      final lastPoint = _currentRoutePoints.last;
      final distance = _calculateDistance(lastPoint.position, location.position);
      _currentRouteDistance += distance;
    }

    // Yeni noktayı ekle
    _currentRoutePoints.add(
      RoutePoint(
        position: location.position,
        altitude: 0.0, // LocationModel'den altitude bilgisi alınabilir
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  /// Keşfedilen alan ekle
  void addExploredArea(LatLng area) {
    if (!_isTracking || _isPaused) return;

    _currentRouteExploredAreas.add(area);
    notifyListeners();
  }

  /// Geçmiş rotaları yükle
  Future<void> loadPastRoutes() async {
    _isLoadingRoutes = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pastRoutes = await _storageService.loadRoutes();
    } catch (e) {
      _errorMessage = 'Rotalar yüklenemedi: $e';
    } finally {
      _isLoadingRoutes = false;
      notifyListeners();
    }
  }

  /// Rota kaydet
  Future<void> saveRoute(RouteModel route) async {
    try {
      await _storageService.saveRoute(route);
      _pastRoutes.add(route);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Rota kaydedilemedi: $e';
      notifyListeners();
    }
  }

  /// Rota sil
  Future<void> deleteRoute(String routeId) async {
    try {
      await _storageService.deleteRoute(routeId);
      _pastRoutes.removeWhere((route) => route.id == routeId);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Rota silinemedi: $e';
      notifyListeners();
    }
  }

  /// Tüm rotaları temizle
  Future<void> clearAllRoutes() async {
    try {
      await _storageService.clearRoutes();
      _pastRoutes.clear();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Rotalar temizlenemedi: $e';
      notifyListeners();
    }
  }

  /// Süre sayacını başlat
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTracking && !_isPaused && _routeStartTime != null) {
        final now = DateTime.now();
        final totalElapsed = now.difference(_routeStartTime!);
        _currentRouteDuration = totalElapsed - _totalPausedTime;
        notifyListeners();
      }
    });
  }

  /// Mola sayacını başlat
  void _startBreakTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused && _pauseStartTime != null) {
        _currentBreakDuration = DateTime.now().difference(_pauseStartTime!);
        notifyListeners();
      }
    });
  }

  /// Rota state'ini sıfırla
  void _resetRouteState() {
    _isTracking = false;
    _isPaused = false;
    _routeStartTime = null;
    _pauseStartTime = null;
    _totalPausedTime = Duration.zero;
    _currentBreakDuration = Duration.zero;
    _currentRouteDistance = 0.0;
    _currentRouteDuration = Duration.zero;
    _currentRoutePoints.clear();
    _currentRouteExploredAreas.clear();
    _durationTimer?.cancel();
    _breakTimer?.cancel();
  }

  /// İki nokta arasındaki mesafeyi hesapla
  double _calculateDistance(LatLng point1, LatLng point2) {
    // Basit hesaplama - gerçek projede Geolocator.distanceBetween kullanılabilir
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * (3.14159265359 / 180);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final double a = (deltaLatRad / 2) * (deltaLatRad / 2) + math.cos(lat1Rad) * math.cos(lat2Rad) * (deltaLngRad / 2) * (deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }
}
