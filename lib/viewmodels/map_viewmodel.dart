import 'package:flutter/material.dart';
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

  // Sıcaklık haritası için geçiş sıklığı takibi
  final Map<String, int> _areaVisitCount = {};
  final Map<String, DateTime> _lastVisitTime = {};

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

    // MapController'ı sadece harita render edildikten sonra kullan
    try {
      _mapController.move(center, _mapState.zoom);
    } catch (e) {
      // MapController henüz hazır değil, sadece state'i güncelle
      debugPrint('MapController henüz hazır değil: $e');
    }

    notifyListeners();
  }

  /// Harita zoom seviyesini güncelle
  void updateMapZoom(double zoom) {
    _mapState = _mapState.copyWith(zoom: zoom);
    if (_mapState.center != null) {
      try {
        _mapController.move(_mapState.center!, zoom);
      } catch (e) {
        debugPrint('MapController henüz hazır değil: $e');
      }
    }
    notifyListeners();
  }

  /// Harita rotasyonunu güncelle
  void updateMapRotation(double rotation) {
    _mapState = _mapState.copyWith(rotation: rotation);
    if (_mapState.center != null) {
      try {
        _mapController.moveAndRotate(_mapState.center!, _mapState.zoom, rotation);
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
  void updateMapWithLocation(LocationModel location) {
    _mapState = _mapState.copyWith(center: location.position);

    if (_mapState.isFollowingLocation) {
      try {
        if (location.bearing != null) {
          _mapController.moveAndRotate(location.position, _mapState.zoom, -location.bearing!);
        } else {
          _mapController.move(location.position, _mapState.zoom);
        }
      } catch (e) {
        debugPrint('MapController henüz hazır değil: $e');
      }
    }

    notifyListeners();
  }

  /// Her adımda alan keşfet (sıcaklık haritası için)
  Future<bool> exploreNewArea(LatLng position) async {
    try {
      // Pozisyonu grid sistemine çevir (daha hassas takip için)
      final gridKey = _getGridKey(position, _settings.explorationRadius / 3);

      // Bu alanın ziyaret sayısını artır
      _areaVisitCount[gridKey] = (_areaVisitCount[gridKey] ?? 0) + 1;
      _lastVisitTime[gridKey] = DateTime.now();

      // Her zaman alanı ekle (sıklık takibi için)
      _exploredAreas = _exploredAreas.addArea(position);

      // Debug: Keşfedilen alan sayısını yazdır
      debugPrint('🗺️ Yeni alan keşfedildi! Grid: $gridKey, Ziyaret: ${_areaVisitCount[gridKey]}, Toplam alan: ${_exploredAreas.areas.length}');

      // Storage'a kaydet (her 10 adımda bir)
      if (_areaVisitCount[gridKey]! % 10 == 1) {
        await _storageService.addExploredArea(position);
      }

      notifyListeners();
      return true; // Her zaman yeni veri eklendi
    } catch (e) {
      _errorMessage = 'Alan kaydedilemedi: $e';
      debugPrint('❌ Alan keşfi hatası: $e');
      notifyListeners();
      return false;
    }
  }

  /// Pozisyonu grid anahtarına çevir
  String _getGridKey(LatLng position, double gridSize) {
    final latGrid = (position.latitude / gridSize).floor();
    final lngGrid = (position.longitude / gridSize).floor();
    return '${latGrid}_$lngGrid';
  }

  /// Bir alanın ziyaret sıklığını al
  int getVisitCount(LatLng position) {
    final gridKey = _getGridKey(position, _settings.explorationRadius / 3);
    return _areaVisitCount[gridKey] ?? 0;
  }

  /// Sıklığa göre renk hesapla
  Color getHeatmapColor(LatLng position) {
    final visitCount = getVisitCount(position);

    if (visitCount == 0) return Colors.transparent;

    // Sıcaklık haritası renkleri: Mavi -> Yeşil -> Sarı -> Kırmızı
    final intensity = (visitCount / 50.0).clamp(0.0, 1.0); // Max 50 ziyaret için normalize

    if (intensity < 0.25) {
      // Mavi -> Cyan
      return Color.lerp(Colors.blue.withValues(alpha: 0.3), Colors.cyan.withValues(alpha: 0.5), intensity * 4)!;
    } else if (intensity < 0.5) {
      // Cyan -> Yeşil
      return Color.lerp(Colors.cyan.withValues(alpha: 0.5), Colors.green.withValues(alpha: 0.6), (intensity - 0.25) * 4)!;
    } else if (intensity < 0.75) {
      // Yeşil -> Sarı
      return Color.lerp(Colors.green.withValues(alpha: 0.6), Colors.yellow.withValues(alpha: 0.7), (intensity - 0.5) * 4)!;
    } else {
      // Sarı -> Kırmızı
      return Color.lerp(Colors.yellow.withValues(alpha: 0.7), Colors.red.withValues(alpha: 0.8), (intensity - 0.75) * 4)!;
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
