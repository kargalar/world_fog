import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_state_model.dart';
import '../models/route_model.dart';

/// Veri saklama işlemlerini yöneten servis sınıfı
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _settingsKey = 'app_settings';
  static const String _exploredAreasKey = 'explored_areas';
  static const String _routesKey = 'saved_routes';

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
  Future<void> saveExploredAreas(List<LatLng> areas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final areasData = areas.map((area) => '${area.latitude},${area.longitude}').toList();
      await prefs.setStringList(_exploredAreasKey, areasData);
    } catch (e) {
      throw StorageException('Keşfedilen alanlar kaydedilemedi: $e');
    }
  }

  /// Keşfedilen alanları yükle
  Future<List<LatLng>> loadExploredAreas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final areasData = prefs.getStringList(_exploredAreasKey) ?? [];
      
      return areasData.map((data) {
        final coords = data.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList();
    } catch (e) {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  /// Keşfedilen alan ekle
  Future<void> addExploredArea(LatLng area) async {
    try {
      final currentAreas = await loadExploredAreas();
      currentAreas.add(area);
      await saveExploredAreas(currentAreas);
    } catch (e) {
      throw StorageException('Keşfedilen alan eklenemedi: $e');
    }
  }

  /// Birden fazla keşfedilen alan ekle
  Future<void> addExploredAreas(List<LatLng> newAreas) async {
    try {
      final currentAreas = await loadExploredAreas();
      currentAreas.addAll(newAreas);
      await saveExploredAreas(currentAreas);
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
}

/// Storage işlemlerinde oluşan hataları temsil eden exception sınıfı
class StorageException implements Exception {
  final String message;
  
  const StorageException(this.message);
  
  @override
  String toString() => 'StorageException: $message';
}
