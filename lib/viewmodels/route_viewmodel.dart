import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

/// Rota işlemlerini yöneten ViewModel
class RouteViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  // Grid exploration callback - Rotanın üzerindeki gridleri keşfetmek için
  Function(LatLng from, LatLng to)? _onRoutePointsAdded;

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
  final List<RouteWaypoint> _currentWaypoints = [];
  double _currentRouteDistance = 0.0;
  Duration _currentRouteDuration = Duration.zero;
  double _totalAscent = 0.0;
  double _totalDescent = 0.0;
  double _lastAltitude = 0.0;

  // Background location buffering
  final List<LocationModel> _locationBuffer = [];
  bool _isBufferingEnabled = false;

  // Pause halinde hareket algılama
  LatLng? _lastPausedPosition;
  bool _movementDetectedWhilePaused = false;
  static const double _movementThreshold = 15.0; // 15 metre hareket eşiği

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
  bool get movementDetectedWhilePaused => _movementDetectedWhilePaused;

  // Getters - Route data
  List<RoutePoint> get currentRoutePoints => List.unmodifiable(_currentRoutePoints);
  List<LatLng> get currentRouteExploredAreas => List.unmodifiable(_currentRouteExploredAreas);
  List<RouteWaypoint> get currentWaypoints => List.unmodifiable(_currentWaypoints);
  double get currentRouteDistance => _currentRouteDistance;
  Duration get currentRouteDuration => _currentRouteDuration;
  int get currentRoutePointsCount => _currentRoutePoints.length;
  double get totalAscent => _totalAscent;
  double get totalDescent => _totalDescent;

  // Ortalama hız (km/h)
  double get currentAverageSpeed {
    if (_currentRouteDuration.inSeconds == 0) return 0.0;
    final movingDuration = _currentRouteDuration - _totalPausedTime;
    if (movingDuration.inSeconds == 0) return 0.0;
    return (_currentRouteDistance / 1000) / (movingDuration.inSeconds / 3600);
  }

  String get formattedAverageSpeed {
    return '${currentAverageSpeed.toStringAsFixed(1)} km/h';
  }

  // Getters - Past routes
  List<RouteModel> get pastRoutes => List.unmodifiable(_pastRoutes);
  bool get isLoadingRoutes => _isLoadingRoutes;
  String? get errorMessage => _errorMessage;
  int get pastRoutesCount => _pastRoutes.length;

  RouteViewModel() {
    _initializeRoutes();
  }

  /// Grid keşif callback'ini ayarla
  void setGridExplorationCallback(Function(LatLng from, LatLng to)? callback) {
    _onRoutePointsAdded = callback;
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
    _totalAscent = 0.0;
    _totalDescent = 0.0;
    _lastAltitude = 0.0;
    _currentRoutePoints.clear();
    _currentRouteExploredAreas.clear();
    _currentWaypoints.clear();

    // Başlangıç noktasını ekle
    if (initialPosition != null) {
      _currentRoutePoints.add(RoutePoint(position: initialPosition, altitude: 0.0, timestamp: DateTime.now()));
    }

    // Süre sayacını başlat
    _startDurationTimer();

    // Bildirim servisini başlat
    _notificationService.startRouteNotification();

    _errorMessage = null;
    notifyListeners();
  }

  /// Rota takibini duraklat
  void pauseTracking() {
    if (!_isTracking || _isPaused) return;

    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _currentBreakDuration = Duration.zero;
    _movementDetectedWhilePaused = false;

    // Son konumu kaydet (pause halinde hareket algılama için)
    if (_currentRoutePoints.isNotEmpty) {
      _lastPausedPosition = _currentRoutePoints.last.position;
    }

    // Mola sayacını başlat
    _startBreakTimer();

    // Bildirimi duraklat
    _notificationService.pauseRouteNotification();

    notifyListeners();
  }

  /// Rota takibini devam ettir
  void resumeTracking() {
    if (!_isTracking || !_isPaused) return;

    _isPaused = false;
    _movementDetectedWhilePaused = false;
    _lastPausedPosition = null;

    // Toplam mola süresini güncelle
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPausedTime += pauseDuration;
    }

    _pauseStartTime = null;
    _currentBreakDuration = Duration.zero;

    // Mola sayacını durdur
    _breakTimer?.cancel();

    // Bildirimi devam ettir (mola hariç geçen süre ile)
    _notificationService.resumeRouteNotification(_currentRouteDuration);

    notifyListeners();
  }

  /// Rota takibini durdur ve kaydet
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    // Timers'ı durdur
    _durationTimer?.cancel();
    _breakTimer?.cancel();

    // Bildirim servisini durdur
    _notificationService.stopRouteNotification();

    // Aktif rota state'ini temizle
    await clearActiveRouteState();

    // Son mola süresini hesapla
    if (_isPaused && _pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPausedTime += pauseDuration;
    }

    // Rota modelini oluştur
    if (_routeStartTime != null && _currentRoutePoints.isNotEmpty) {
      final route = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Route ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        routePoints: List.from(_currentRoutePoints),
        exploredAreas: List.from(_currentRouteExploredAreas),
        waypoints: List.from(_currentWaypoints),
        totalDistance: _currentRouteDistance,
        totalDuration: _currentRouteDuration,
        totalBreakTime: _totalPausedTime,
        totalAscent: _totalAscent,
        totalDescent: _totalDescent,
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

  /// Rota takibini durdur ve özel isimle kaydet
  Future<RouteModel?> stopTrackingWithName(String name, {WeatherInfo? weather, int? rating}) async {
    if (!_isTracking) return null;

    // Timers'ı durdur
    _durationTimer?.cancel();
    _breakTimer?.cancel();

    // Bildirim servisini durdur
    _notificationService.stopRouteNotification();

    // Aktif rota state'ini temizle
    await clearActiveRouteState();

    // Son mola süresini hesapla
    if (_isPaused && _pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPausedTime += pauseDuration;
    }

    RouteModel? savedRoute;

    // Rota modelini oluştur
    if (_routeStartTime != null && _currentRoutePoints.isNotEmpty) {
      savedRoute = RouteModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        routePoints: List.from(_currentRoutePoints),
        exploredAreas: List.from(_currentRouteExploredAreas),
        waypoints: List.from(_currentWaypoints),
        totalDistance: _currentRouteDistance,
        totalDuration: _currentRouteDuration,
        totalBreakTime: _totalPausedTime,
        totalAscent: _totalAscent,
        totalDescent: _totalDescent,
        weather: weather,
        rating: rating,
        startTime: _routeStartTime!,
        endTime: DateTime.now(),
      );

      // Rotayı kaydet
      await saveRoute(savedRoute);
    }

    // State'i sıfırla
    _resetRouteState();
    notifyListeners();

    return savedRoute;
  }

  /// Arkaplan konum tamponlamasını etkinleştir
  void enableLocationBuffering() {
    _isBufferingEnabled = true;
    debugPrint('📍 Location buffering enabled');
  }

  /// Tamponlanmış konumları işle (uygulama ön plana geldiğinde)
  void processBufferedLocations() {
    if (_locationBuffer.isEmpty) {
      _isBufferingEnabled = false;
      return;
    }

    debugPrint('📍 Processing ${_locationBuffer.length} buffered locations');

    // Tamponlanmış tüm konumları sırayla işle
    for (final location in _locationBuffer) {
      _addLocationPointInternal(location);
    }

    _locationBuffer.clear();
    _isBufferingEnabled = false;
    notifyListeners();
  }

  /// Yeni konum noktası ekle
  void addLocationPoint(LocationModel location) {
    if (!_isTracking) return;

    // Arkaplan modundayken tampona ekle
    if (_isBufferingEnabled) {
      _locationBuffer.add(location);
      debugPrint('📍 Buffered location: ${location.position.latitude}, ${location.position.longitude}');
      return;
    }

    // Pause halinde hareket kontrolü ve rota çizimi (istatistikler hariç)
    if (_isPaused) {
      _checkMovementWhilePaused(location.position);
      _addLocationPointWhilePaused(location);
      return;
    }

    _addLocationPointInternal(location);
  }

  /// Pause halinde hareket kontrolü
  void _checkMovementWhilePaused(LatLng currentPosition) {
    if (_lastPausedPosition == null) {
      _lastPausedPosition = currentPosition;
      return;
    }

    final distance = Geolocator.distanceBetween(_lastPausedPosition!.latitude, _lastPausedPosition!.longitude, currentPosition.latitude, currentPosition.longitude);

    if (distance > _movementThreshold && !_movementDetectedWhilePaused) {
      _movementDetectedWhilePaused = true;
      debugPrint('⚠️ Pause halinde hareket algılandı: ${distance.toStringAsFixed(1)}m');
      notifyListeners();
    }
  }

  /// Pause halinde konum noktası ekle (istatistikler hesaplanmaz, sadece rota çizilir)
  void _addLocationPointWhilePaused(LocationModel location) {
    LatLng? lastPointPosition;
    double currentAltitude = location.altitude ?? 0.0;

    if (_currentRoutePoints.isNotEmpty) {
      lastPointPosition = _currentRoutePoints.last.position;
    }

    // Yeni noktayı ekle (mesafe ve yükseklik istatistikleri hesaplanmaz)
    _currentRoutePoints.add(RoutePoint(position: location.position, altitude: currentAltitude, timestamp: location.timestamp));

    // Rotanın üzerindeki gridleri keşfet
    if (lastPointPosition != null && _onRoutePointsAdded != null) {
      _onRoutePointsAdded!(lastPointPosition, location.position);
    }

    notifyListeners();
  }

  /// Hareket uyarısını temizle
  void clearMovementWarning() {
    _movementDetectedWhilePaused = false;
    if (_currentRoutePoints.isNotEmpty) {
      _lastPausedPosition = _currentRoutePoints.last.position;
    }
    notifyListeners();
  }

  /// İç konum noktası ekleme metodu
  void _addLocationPointInternal(LocationModel location) {
    if (!_isTracking || _isPaused) return;

    LatLng? lastPointPosition;
    double currentAltitude = location.altitude ?? 0.0;

    debugPrint('🏔️ Yükseklik verisi: ${location.altitude} -> currentAltitude: $currentAltitude');

    // İlk nokta için lastAltitude'u ayarla
    if (_currentRoutePoints.isEmpty) {
      _lastAltitude = currentAltitude;
    }

    // Mesafe ve yükseklik hesapla
    if (_currentRoutePoints.isNotEmpty) {
      final lastPoint = _currentRoutePoints.last;
      lastPointPosition = lastPoint.position;
      final distance = _calculateDistance(lastPoint.position, location.position);
      _currentRouteDistance += distance;

      // Yükseklik değişimini hesapla (küçük gürültüleri filtrele)
      final altitudeDiff = currentAltitude - _lastAltitude;
      // Sadece 1 metreden fazla yükseklik değişikliklerini say (GPS gürültüsünü filtrele)
      if (altitudeDiff.abs() > 1.0) {
        if (altitudeDiff > 0) {
          _totalAscent += altitudeDiff;
          debugPrint('📈 Tırmanış: +${altitudeDiff.toStringAsFixed(1)}m (Toplam: ${_totalAscent.toStringAsFixed(1)}m)');
        } else {
          _totalDescent += altitudeDiff.abs();
          debugPrint('📉 İniş: -${altitudeDiff.abs().toStringAsFixed(1)}m (Toplam: ${_totalDescent.toStringAsFixed(1)}m)');
        }
        _lastAltitude = currentAltitude;
      }
    }

    // Yeni noktayı ekle
    _currentRoutePoints.add(RoutePoint(position: location.position, altitude: currentAltitude, timestamp: location.timestamp));

    // Rotanın üzerindeki gridleri keşfet (bir önceki noktadan mevcut noktaya kadar)
    if (lastPointPosition != null && _onRoutePointsAdded != null) {
      _onRoutePointsAdded!(lastPointPosition, location.position);
    }

    // Bildirimi güncelle
    _notificationService.updateRouteNotification(_currentRouteDuration);

    notifyListeners();
  }

  /// Waypoint (fotoğraf işareti) ekle
  void addWaypoint(RouteWaypoint waypoint) {
    if (!_isTracking) return;
    _currentWaypoints.add(waypoint);
    notifyListeners();
  }

  /// Waypoint sil
  void removeWaypoint(String waypointId) {
    _currentWaypoints.removeWhere((w) => w.id == waypointId);
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
    _totalAscent = 0.0;
    _totalDescent = 0.0;
    _lastAltitude = 0.0;
    _currentRoutePoints.clear();
    _currentRouteExploredAreas.clear();
    _currentWaypoints.clear();
    _locationBuffer.clear();
    _isBufferingEnabled = false;
    _movementDetectedWhilePaused = false;
    _lastPausedPosition = null;
    _durationTimer?.cancel();
    _breakTimer?.cancel();
  }

  /// Rota takibini kaydetmeden iptal et
  void cancelTracking() {
    if (!_isTracking) return;

    // Timers'ı durdur
    _durationTimer?.cancel();
    _breakTimer?.cancel();

    // Bildirim servisini durdur
    _notificationService.stopRouteNotification();

    // Aktif rota state'ini temizle
    clearActiveRouteState();

    // State'i sıfırla
    _resetRouteState();
    notifyListeners();
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

  /// Aktif rota state'ini kaydet (uygulama kapanırken)
  Future<void> saveActiveRouteState() async {
    if (!_isTracking) {
      await _storageService.clearActiveRouteState();
      return;
    }

    try {
      final state = ActiveRouteState(
        isTracking: _isTracking,
        isPaused: _isPaused,
        routeStartTime: _routeStartTime,
        pauseStartTime: _pauseStartTime,
        totalPausedTime: _totalPausedTime,
        routePoints: List.from(_currentRoutePoints),
        exploredAreas: List.from(_currentRouteExploredAreas),
        waypoints: List.from(_currentWaypoints),
        totalDistance: _currentRouteDistance,
        totalAscent: _totalAscent,
        totalDescent: _totalDescent,
        lastAltitude: _lastAltitude,
      );
      await _storageService.saveActiveRouteState(state);
      debugPrint('💾 Aktif rota state kaydedildi');
    } catch (e) {
      debugPrint('❌ Aktif rota state kaydedilemedi: $e');
    }
  }

  /// Aktif rota state'ini geri yükle (uygulama açılırken)
  Future<bool> restoreActiveRouteState() async {
    try {
      final state = await _storageService.loadActiveRouteState();
      if (state == null || !state.isTracking) {
        return false;
      }

      _isTracking = state.isTracking;
      _isPaused = state.isPaused;
      _routeStartTime = state.routeStartTime;
      _pauseStartTime = state.pauseStartTime;
      _totalPausedTime = state.totalPausedTime;
      _currentRoutePoints.addAll(state.routePoints);
      _currentRouteExploredAreas.addAll(state.exploredAreas);
      _currentWaypoints.addAll(state.waypoints);
      _currentRouteDistance = state.totalDistance;
      _totalAscent = state.totalAscent;
      _totalDescent = state.totalDescent;
      _lastAltitude = state.lastAltitude;

      // Süre hesapla
      if (_routeStartTime != null) {
        final now = DateTime.now();
        final totalElapsed = now.difference(_routeStartTime!);

        // Eğer pause halindeyse, pause süresini hesapla
        if (_isPaused && _pauseStartTime != null) {
          final pauseDuration = now.difference(_pauseStartTime!);
          _currentBreakDuration = pauseDuration;
        }

        _currentRouteDuration = totalElapsed - _totalPausedTime;
      }

      // Timer'ları başlat
      _startDurationTimer();
      if (_isPaused) {
        _startBreakTimer();
      }

      // Bildirimi başlat
      if (!_isPaused) {
        _notificationService.startRouteNotification();
      }

      debugPrint('✅ Aktif rota state geri yüklendi: ${_currentRoutePoints.length} nokta');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Aktif rota state geri yüklenemedi: $e');
      return false;
    }
  }

  /// Aktif rota state'ini temizle
  Future<void> clearActiveRouteState() async {
    await _storageService.clearActiveRouteState();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }
}
