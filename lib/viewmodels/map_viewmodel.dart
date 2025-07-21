import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_state_model.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';

/// Harita işlemlerini yöneten ViewModel
class MapViewModel extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final MapController _mapController = MapController();

  // State variables
  MapStateModel _mapState = const MapStateModel();
  ExploredAreaModel _exploredAreas = ExploredAreaModel(areas: [], lastUpdated: DateTime.now());
  AppSettingsModel _settings = const AppSettingsModel();
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  MapController get mapController => _mapController;
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
  List<LatLng> get exploredAreasList => _exploredAreas.areas;
  int get exploredAreasCount => _exploredAreas.areas.length;
  DateTime get lastExplorationUpdate => _exploredAreas.lastUpdated;

  MapViewModel() {
    _initializeMap();
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
      final areas = await _storageService.loadExploredAreas();
      _exploredAreas = ExploredAreaModel(areas: areas, lastUpdated: DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('Keşfedilen alanlar yüklenemedi: $e');
    }
  }

  /// Harita merkezini güncelle
  void updateMapCenter(LatLng center, {double? zoom}) {
    _mapState = _mapState.copyWith(center: center, zoom: zoom ?? _mapState.zoom);

    _mapController.move(center, _mapState.zoom);
    notifyListeners();
  }

  /// Harita zoom seviyesini güncelle
  void updateMapZoom(double zoom) {
    _mapState = _mapState.copyWith(zoom: zoom);
    if (_mapState.center != null) {
      _mapController.move(_mapState.center!, zoom);
    }
    notifyListeners();
  }

  /// Harita rotasyonunu güncelle
  void updateMapRotation(double rotation) {
    _mapState = _mapState.copyWith(rotation: rotation);
    if (_mapState.center != null) {
      _mapController.moveAndRotate(_mapState.center!, _mapState.zoom, rotation);
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
  void updateMapWithLocation(LocationModel location) {
    _mapState = _mapState.copyWith(center: location.position);

    if (_mapState.isFollowingLocation) {
      if (location.bearing != null) {
        _mapController.moveAndRotate(location.position, _mapState.zoom, -location.bearing!);
      } else {
        _mapController.move(location.position, _mapState.zoom);
      }
    }

    notifyListeners();
  }

  /// Yeni alan keşfet
  Future<bool> exploreNewArea(LatLng position) async {
    try {
      // Daha önce keşfedilmiş mi kontrol et
      if (_exploredAreas.isAreaExplored(position, _settings.explorationRadius)) {
        return false; // Zaten keşfedilmiş
      }

      // Yeni alanı ekle
      _exploredAreas = _exploredAreas.addArea(position);

      // Storage'a kaydet
      await _storageService.addExploredArea(position);

      notifyListeners();
      return true; // Yeni alan keşfedildi
    } catch (e) {
      _errorMessage = 'Yeni alan kaydedilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Birden fazla alan keşfet
  Future<int> exploreNewAreas(List<LatLng> positions) async {
    try {
      int newAreasCount = 0;
      List<LatLng> newAreas = [];

      for (final position in positions) {
        if (!_exploredAreas.isAreaExplored(position, _settings.explorationRadius)) {
          newAreas.add(position);
          newAreasCount++;
        }
      }

      if (newAreas.isNotEmpty) {
        _exploredAreas = _exploredAreas.addAreas(newAreas);
        await _storageService.addExploredAreas(newAreas);
        notifyListeners();
      }

      return newAreasCount;
    } catch (e) {
      _errorMessage = 'Yeni alanlar kaydedilemedi: $e';
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
      _exploredAreas = ExploredAreaModel(areas: [], lastUpdated: DateTime.now());
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
