import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/app_state_model.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';

/// Harita işlemlerini yöneten ViewModel
class MapViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();

  // State variables
  MapStateModel _mapState = const MapStateModel();
  ExploredAreaModel _exploredAreas = ExploredAreaModel(exploredGrids: {}, lastUpdated: DateTime.now());
  AppSettingsModel _settings = const AppSettingsModel();
  bool _isLoading = false;
  String? _errorMessage;

  // Grid boyutu: 0.125km² için yaklaşık 0.0032 derece (354m / 111320m)
  static const double _gridSizeDegrees = 0.0032;

  // Getters
  Completer<GoogleMapController> get mapControllerCompleter => _mapControllerCompleter;
  MapStateModel get mapState => _mapState;
  ExploredAreaModel get exploredAreas => _exploredAreas;
  AppSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Map state getters
  LatLng? get center => _mapState.center;
  double get zoom => _mapState.zoom;
  double get rotation => _mapState.rotation;
  bool get isFollowingLocation => _mapState.isFollowingLocation;
  bool get showPastRoutes => _mapState.showPastRoutes;

  // Explored areas getters
  Set<String> get exploredGrids => _exploredAreas.exploredGrids;
  int get exploredAreasCount => _exploredAreas.exploredGrids.length;
  DateTime get lastExplorationUpdate => _exploredAreas.lastUpdated;

  MapViewModel() {
    _initializeMap();
  }

  /// GoogleMapController'ı ayarla
  void setMapController(GoogleMapController controller) {
    if (!_mapControllerCompleter.isCompleted) {
      _mapControllerCompleter.complete(controller);
    }
  }

  /// Harita ve verileri başlat
  Future<void> _initializeMap() async {
    _setLoading(true);
    try {
      await _loadSettings();
      await _loadExploredAreas();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Harita başlatılamadı: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Ayarları yükle
  Future<void> _loadSettings() async {
    try {
      _settings = await _storageService.loadSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Ayarlar yüklenemedi: $e');
    }
  }

  /// Keşfedilen alanları yükle
  Future<void> _loadExploredAreas() async {
    try {
      final grids = await _storageService.loadExploredAreas();
      _exploredAreas = ExploredAreaModel(exploredGrids: grids, lastUpdated: DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('Keşfedilen alanlar yüklenemedi: $e');
    }
  }

  /// Harita merkezini güncelle
  Future<void> updateMapCenter(LatLng center, {double? zoom}) async {
    _mapState = _mapState.copyWith(center: center, zoom: zoom ?? _mapState.zoom);

    // MapController'ı sadece harita render edildikten sonra kullan
    try {
      if (_mapControllerCompleter.isCompleted) {
        final controller = await _mapControllerCompleter.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: center, zoom: _mapState.zoom, bearing: _mapState.rotation)));
      }
    } catch (e) {
      // MapController henüz hazır değil, sadece state'i güncelle
      debugPrint('MapController henüz hazır değil: $e');
    }

    notifyListeners();
  }

  /// Harita zoom seviyesini güncelle
  Future<void> updateMapZoom(double zoom) async {
    _mapState = _mapState.copyWith(zoom: zoom);
    if (_mapState.center != null) {
      try {
        if (_mapControllerCompleter.isCompleted) {
          final controller = await _mapControllerCompleter.future;
          controller.animateCamera(CameraUpdate.zoomTo(zoom));
        }
      } catch (e) {
        debugPrint('MapController henüz hazır değil: $e');
      }
    }
    notifyListeners();
  }

  /// Harita rotasyonunu güncelle
  Future<void> updateMapRotation(double rotation) async {
    _mapState = _mapState.copyWith(rotation: rotation);
    if (_mapState.center != null) {
      try {
        if (_mapControllerCompleter.isCompleted) {
          final controller = await _mapControllerCompleter.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _mapState.center!, zoom: _mapState.zoom, bearing: rotation)));
        }
      } catch (e) {
        debugPrint('MapController henüz hazır değil: $e');
      }
    }
    notifyListeners();
  }

  /// Konum takibini aç/kapat
  void toggleLocationFollowing() {
    _mapState = _mapState.copyWith(isFollowingLocation: !_mapState.isFollowingLocation);
    notifyListeners();
  }

  /// Konum takibini ayarla
  void setLocationFollowing(bool following) {
    _mapState = _mapState.copyWith(isFollowingLocation: following);
    notifyListeners();
  }

  /// Geçmiş rotaları göster/gizle
  void togglePastRoutes() {
    _mapState = _mapState.copyWith(showPastRoutes: !_mapState.showPastRoutes);
    notifyListeners();
  }

  /// Geçmiş rotaları göstermeyi ayarla
  void setPastRoutesVisibility(bool show) {
    _mapState = _mapState.copyWith(showPastRoutes: show);
    notifyListeners();
  }

  /// Konuma göre haritayı güncelle
  Future<void> updateMapWithLocation(LocationModel location) async {
    _mapState = _mapState.copyWith(center: location.position);

    if (_mapState.isFollowingLocation) {
      try {
        if (_mapControllerCompleter.isCompleted) {
          final controller = await _mapControllerCompleter.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: location.position, zoom: _mapState.zoom, bearing: location.bearing ?? 0)));
        }
      } catch (e) {
        debugPrint('MapController henüz hazır değil: $e');
      }
    }

    notifyListeners();
  }

  /// Her adımda grid keşfet
  Future<bool> exploreNewGrid(LatLng position) async {
    try {
      // Pozisyonu grid sistemine çevir
      final gridKey = _getGridKey(position, _gridSizeDegrees);

      // Bu grid zaten keşfedilmiş mi kontrol et
      if (_exploredAreas.isGridExplored(gridKey)) {
        return false; // Zaten keşfedilmiş
      }

      // Grid'i keşfedilenlere ekle
      _exploredAreas = _exploredAreas.addGrid(gridKey);

      // Debug: Keşfedilen grid sayısını yazdır
      debugPrint('🗺️ Yeni grid keşfedildi! Grid: $gridKey, Toplam grid: ${_exploredAreas.exploredGrids.length}');

      // Storage'a kaydet
      await _storageService.addExploredArea(gridKey);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Grid kaydedilemedi: $e';
      debugPrint('❌ Grid keşfi hatası: $e');
      notifyListeners();
      return false;
    }
  }

  /// Rotanın üzerindeki tüm gridleri keşfet (iki nokta arasında interpolasyon yaparak)
  Future<void> exploreRouteGrids(LatLng from, LatLng to) async {
    try {
      // Başlangıç ve bitiş grid'lerini al
      final startGridKey = _getGridKey(from, _gridSizeDegrees);
      final endGridKey = _getGridKey(to, _gridSizeDegrees);

      // Başlangıç ve bitiş noktalarını keşfet
      await exploreNewGrid(from);
      if (startGridKey != endGridKey) {
        await exploreNewGrid(to);
      }

      // İki nokta arasındaki interpolasyon
      final distance = _calculateDistance(from, to);
      if (distance > 0) {
        // Adım sayısını hesapla (grid boyutuna göre)
        final steps = (distance / (_gridSizeDegrees * 111320)).ceil(); // 111320m = 1 derece

        for (int i = 1; i < steps; i++) {
          // Interpolate edilen noktayı hesapla
          final progress = i / steps;
          final latInterpolated = from.latitude + (to.latitude - from.latitude) * progress;
          final lngInterpolated = from.longitude + (to.longitude - from.longitude) * progress;
          final interpolatedPoint = LatLng(latInterpolated, lngInterpolated);

          // Bu grid'i keşfet
          await exploreNewGrid(interpolatedPoint);
        }
      }
    } catch (e) {
      _errorMessage = 'Rota grid keşfi başarısız: $e';
      debugPrint('❌ Rota keşfi hatası: $e');
      notifyListeners();
    }
  }

  /// İki nokta arasındaki mesafeyi hesapla (metre cinsinden - Haversine formülü)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - math.cos((point2.latitude - point1.latitude) * p) / 2 + math.cos(point1.latitude * p) * math.cos(point2.latitude * p) * (1 - math.cos((point2.longitude - point1.longitude) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // 2 * R * asin; R=6371 km
  }

  /// Pozisyonu grid anahtarına çevir
  String _getGridKey(LatLng position, double gridSize) {
    final latGrid = (position.latitude / gridSize).floor();
    final lngGrid = (position.longitude / gridSize).floor();
    return '${latGrid}_$lngGrid';
  }

  /// Birden fazla alan keşfet
  Future<int> exploreNewAreas(List<LatLng> positions) async {
    try {
      int newGridsCount = 0;
      Set<String> newGrids = {};

      for (final position in positions) {
        final gridKey = _getGridKey(position, _gridSizeDegrees);
        if (!_exploredAreas.isGridExplored(gridKey)) {
          newGrids.add(gridKey);
          newGridsCount++;
        }
      }

      if (newGrids.isNotEmpty) {
        _exploredAreas = ExploredAreaModel(exploredGrids: {..._exploredAreas.exploredGrids, ...newGrids}, lastUpdated: DateTime.now());
        await _storageService.addExploredAreas(newGrids);
        notifyListeners();
      }

      return newGridsCount;
    } catch (e) {
      _errorMessage = 'Yeni gridler kaydedilemedi: $e';
      notifyListeners();
      return 0;
    }
  }

  /// Ayarları güncelle
  Future<void> updateSettings(AppSettingsModel newSettings) async {
    try {
      _settings = newSettings;
      await _storageService.saveSettings(newSettings);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ayarlar kaydedilemedi: $e';
      notifyListeners();
    }
  }

  /// Keşif yarıçapını güncelle
  Future<void> updateExplorationRadius(double radius) async {
    final newSettings = _settings.copyWith(explorationRadius: radius);
    await updateSettings(newSettings);
  }

  /// Alan opaklığını güncelle
  Future<void> updateAreaOpacity(double opacity) async {
    final newSettings = _settings.copyWith(areaOpacity: opacity);
    await updateSettings(newSettings);
  }

  /// Mesafe filtresini güncelle
  Future<void> updateDistanceFilter(double filter) async {
    final newSettings = _settings.copyWith(distanceFilter: filter);
    await updateSettings(newSettings);
  }

  /// Keşfedilen alanları temizle
  Future<void> clearExploredAreas() async {
    try {
      await _storageService.clearExploredAreas();
      _exploredAreas = ExploredAreaModel(exploredGrids: {}, lastUpdated: DateTime.now());
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Keşfedilen alanlar temizlenemedi: $e';
      notifyListeners();
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Loading durumunu ayarla
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Haritayı yenile
  Future<void> refreshMap() async {
    await _initializeMap();
  }
}
