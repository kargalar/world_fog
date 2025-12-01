import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state_model.dart';
import '../models/route_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Veri saklama işlemlerini yöneten servis sınıfı
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _settingsKey = 'app_settings';
  static const String _exploredAreasKey = 'explored_areas';
  static const String _routesKey = 'saved_routes';
  static const String _activeRouteKey = 'active_route_state';
  static const String _lastLocationKey = 'last_known_location';

  /// Uygulama ayarlarını kaydet
  Future<void> saveSettings(AppSettingsModel settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      throw StorageException('Ayarlar kaydedilemedi: $e');
    }
  }

  /// Uygulama ayarlarını yükle
  Future<AppSettingsModel> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson == null) {
        return const AppSettingsModel(); // Varsayılan ayarlar
      }

      final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
      return AppSettingsModel.fromJson(settingsMap);
    } catch (e) {
      // Hata durumunda varsayılan ayarları döndür
      return const AppSettingsModel();
    }
  }

  /// Keşfedilen alanları kaydet
  Future<void> saveExploredAreas(Set<String> grids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gridsData = grids.toList();
      await prefs.setStringList(_exploredAreasKey, gridsData);
    } catch (e) {
      throw StorageException('Keşfedilen alanlar kaydedilemedi: $e');
    }
  }

  /// Keşfedilen alanları yükle
  Future<Set<String>> loadExploredAreas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gridsData = prefs.getStringList(_exploredAreasKey) ?? [];

      return gridsData.toSet();
    } catch (e) {
      // Hata durumunda boş set döndür
      return {};
    }
  }

  /// Keşfedilen alan ekle
  Future<void> addExploredArea(String gridKey) async {
    try {
      final currentGrids = await loadExploredAreas();
      currentGrids.add(gridKey);
      await saveExploredAreas(currentGrids);
    } catch (e) {
      throw StorageException('Keşfedilen alan eklenemedi: $e');
    }
  }

  /// Birden fazla keşfedilen alan ekle
  Future<void> addExploredAreas(Set<String> newGrids) async {
    try {
      final currentGrids = await loadExploredAreas();
      currentGrids.addAll(newGrids);
      await saveExploredAreas(currentGrids);
    } catch (e) {
      throw StorageException('Keşfedilen alanlar eklenemedi: $e');
    }
  }

  /// Rotaları kaydet
  Future<void> saveRoutes(List<RouteModel> routes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = routes.map((route) => route.toJson()).toList();
      final routesString = json.encode(routesJson);
      await prefs.setString(_routesKey, routesString);
    } catch (e) {
      throw StorageException('Rotalar kaydedilemedi: $e');
    }
  }

  /// Rotaları yükle
  Future<List<RouteModel>> loadRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesString = prefs.getString(_routesKey);

      if (routesString == null) {
        return [];
      }

      final routesJson = json.decode(routesString) as List<dynamic>;
      return routesJson.map((routeJson) => RouteModel.fromJson(routeJson as Map<String, dynamic>)).toList();
    } catch (e) {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  /// Rota kaydet
  Future<void> saveRoute(RouteModel route) async {
    try {
      final currentRoutes = await loadRoutes();
      currentRoutes.add(route);
      await saveRoutes(currentRoutes);
    } catch (e) {
      throw StorageException('Rota kaydedilemedi: $e');
    }
  }

  /// Rota sil
  Future<void> deleteRoute(String routeId) async {
    try {
      final currentRoutes = await loadRoutes();
      currentRoutes.removeWhere((route) => route.id == routeId);
      await saveRoutes(currentRoutes);
    } catch (e) {
      throw StorageException('Rota silinemedi: $e');
    }
  }

  /// Tüm verileri temizle
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
      await prefs.remove(_exploredAreasKey);
      await prefs.remove(_routesKey);
    } catch (e) {
      throw StorageException('Veriler temizlenemedi: $e');
    }
  }

  /// Sadece keşfedilen alanları temizle
  Future<void> clearExploredAreas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_exploredAreasKey);
    } catch (e) {
      throw StorageException('Keşfedilen alanlar temizlenemedi: $e');
    }
  }

  /// Sadece rotaları temizle
  Future<void> clearRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_routesKey);
    } catch (e) {
      throw StorageException('Rotalar temizlenemedi: $e');
    }
  }

  /// Belirli bir ayarı kaydet
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        throw StorageException('Desteklenmeyen veri tipi: ${value.runtimeType}');
      }
    } catch (e) {
      throw StorageException('Ayar kaydedilemedi: $e');
    }
  }

  /// Belirli bir ayarı yükle
  Future<T?> loadSetting<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.get(key) as T?;
    } catch (e) {
      return null;
    }
  }

  /// Aktif rota state'ini kaydet
  Future<void> saveActiveRouteState(ActiveRouteState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = json.encode(state.toJson());
      await prefs.setString(_activeRouteKey, stateJson);
    } catch (e) {
      throw StorageException('Aktif rota state kaydedilemedi: $e');
    }
  }

  /// Aktif rota state'ini yükle
  Future<ActiveRouteState?> loadActiveRouteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_activeRouteKey);

      if (stateJson == null) {
        return null;
      }

      final stateMap = json.decode(stateJson) as Map<String, dynamic>;
      return ActiveRouteState.fromJson(stateMap);
    } catch (e) {
      return null;
    }
  }

  /// Aktif rota state'ini temizle
  Future<void> clearActiveRouteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeRouteKey);
    } catch (e) {
      throw StorageException('Aktif rota state temizlenemedi: $e');
    }
  }

  /// Son bilinen konumu kaydet
  Future<void> saveLastKnownLocation(LatLng location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = json.encode({'latitude': location.latitude, 'longitude': location.longitude});
      await prefs.setString(_lastLocationKey, locationJson);
    } catch (e) {
      throw StorageException('Son konum kaydedilemedi: $e');
    }
  }

  /// Son bilinen konumu yükle
  Future<LatLng?> loadLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_lastLocationKey);

      if (locationJson == null) {
        return null;
      }

      final locationMap = json.decode(locationJson) as Map<String, dynamic>;
      return LatLng(locationMap['latitude'] as double, locationMap['longitude'] as double);
    } catch (e) {
      return null;
    }
  }
}

/// Aktif rota state modeli
class ActiveRouteState {
  final bool isTracking;
  final bool isPaused;
  final DateTime? routeStartTime;
  final DateTime? pauseStartTime;
  final Duration totalPausedTime;
  final List<RoutePoint> routePoints;
  final List<LatLng> exploredAreas;
  final List<RouteWaypoint> waypoints;
  final double totalDistance;
  final double totalAscent;
  final double totalDescent;
  final double lastAltitude;

  const ActiveRouteState({
    required this.isTracking,
    required this.isPaused,
    this.routeStartTime,
    this.pauseStartTime,
    required this.totalPausedTime,
    required this.routePoints,
    required this.exploredAreas,
    required this.waypoints,
    required this.totalDistance,
    required this.totalAscent,
    required this.totalDescent,
    required this.lastAltitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'isTracking': isTracking,
      'isPaused': isPaused,
      'routeStartTime': routeStartTime?.toIso8601String(),
      'pauseStartTime': pauseStartTime?.toIso8601String(),
      'totalPausedTimeMs': totalPausedTime.inMilliseconds,
      'routePoints': routePoints.map((p) => {'lat': p.position.latitude, 'lng': p.position.longitude, 'altitude': p.altitude, 'timestamp': p.timestamp.toIso8601String()}).toList(),
      'exploredAreas': exploredAreas.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'totalDistance': totalDistance,
      'totalAscent': totalAscent,
      'totalDescent': totalDescent,
      'lastAltitude': lastAltitude,
    };
  }

  factory ActiveRouteState.fromJson(Map<String, dynamic> json) {
    return ActiveRouteState(
      isTracking: json['isTracking'] as bool,
      isPaused: json['isPaused'] as bool,
      routeStartTime: json['routeStartTime'] != null ? DateTime.parse(json['routeStartTime'] as String) : null,
      pauseStartTime: json['pauseStartTime'] != null ? DateTime.parse(json['pauseStartTime'] as String) : null,
      totalPausedTime: Duration(milliseconds: json['totalPausedTimeMs'] as int),
      routePoints: (json['routePoints'] as List<dynamic>).map((p) => RoutePoint(position: LatLng(p['lat'] as double, p['lng'] as double), altitude: p['altitude'] as double, timestamp: DateTime.parse(p['timestamp'] as String))).toList(),
      exploredAreas: (json['exploredAreas'] as List<dynamic>).map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList(),
      waypoints: (json['waypoints'] as List<dynamic>).map((w) => RouteWaypoint.fromJson(w as Map<String, dynamic>)).toList(),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      totalAscent: (json['totalAscent'] as num).toDouble(),
      totalDescent: (json['totalDescent'] as num).toDouble(),
      lastAltitude: (json['lastAltitude'] as num).toDouble(),
    );
  }
}

/// Storage işlemlerinde oluşan hataları temsil eden exception sınıfı
class StorageException implements Exception {
  final String message;

  const StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}
