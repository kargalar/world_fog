import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/route_model.dart';

class RouteService {
  static const String _routesKey = 'saved_routes';

  static Future<List<RouteModel>> getSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesString = prefs.getString(_routesKey);

    if (routesString == null) {
      return [];
    }

    try {
      final routesJson = jsonDecode(routesString) as List<dynamic>;
      return routesJson.map((routeJson) => RouteModel.fromJson(routeJson as Map<String, dynamic>)).toList();
    } catch (e) {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  static Future<void> saveRoute(RouteModel route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();

    // Aynı ID'ye sahip rota varsa güncelle
    final existingIndex = routes.indexWhere((r) => r.id == route.id);
    if (existingIndex != -1) {
      routes[existingIndex] = route;
    } else {
      routes.add(route);
    }

    final routesJson = routes.map((route) => route.toJson()).toList();
    final routesString = jsonEncode(routesJson);
    await prefs.setString(_routesKey, routesString);
  }

  static Future<void> deleteRoute(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();

    routes.removeWhere((route) => route.id == routeId);

    final routesJson = routes.map((route) => route.toJson()).toList();
    final routesString = jsonEncode(routesJson);
    await prefs.setString(_routesKey, routesString);
  }

  static Future<RouteModel?> getRoute(String routeId) async {
    final routes = await getSavedRoutes();
    try {
      return routes.firstWhere((route) => route.id == routeId);
    } catch (e) {
      return null;
    }
  }

  /// Tüm rotaları JSON dosyası olarak dışa aktarır
  static Future<String?> exportRoutes() async {
    try {
      final routes = await getSavedRoutes();
      if (routes.isEmpty) {
        return null;
      }

      final exportData = {'version': '1.0', 'exportDate': DateTime.now().toIso8601String(), 'routeCount': routes.length, 'routes': routes.map((route) => route.toJson()).toList()};

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Geçici dosya oluştur
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/worldfog_routes_$timestamp.json');
      await file.writeAsString(jsonString);

      // Dosyayı paylaş
      await Share.shareXFiles([XFile(file.path)], subject: 'World Fog Routes Export');

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// JSON dosyasından rotaları içe aktarır
  static Future<ImportResult> importRoutes({bool replaceExisting = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Versiyon kontrolü
      final version = importData['version'] as String?;
      if (version == null) {
        return ImportResult(success: false, message: 'Invalid file format');
      }

      final routesJson = importData['routes'] as List<dynamic>?;
      if (routesJson == null || routesJson.isEmpty) {
        return ImportResult(success: false, message: 'No routes found in file');
      }

      final importedRoutes = routesJson.map((json) => RouteModel.fromJson(json as Map<String, dynamic>)).toList();

      if (replaceExisting) {
        // Mevcut rotaları sil ve yenileri ekle
        final prefs = await SharedPreferences.getInstance();
        final routesJsonList = importedRoutes.map((route) => route.toJson()).toList();
        await prefs.setString(_routesKey, jsonEncode(routesJsonList));
        return ImportResult(success: true, message: 'Imported ${importedRoutes.length} routes (replaced existing)', importedCount: importedRoutes.length);
      } else {
        // Mevcut rotalara ekle (aynı ID'li olanları atla)
        final existingRoutes = await getSavedRoutes();
        final existingIds = existingRoutes.map((r) => r.id).toSet();

        int addedCount = 0;
        int skippedCount = 0;

        for (final route in importedRoutes) {
          if (existingIds.contains(route.id)) {
            skippedCount++;
          } else {
            existingRoutes.add(route);
            addedCount++;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final routesJsonList = existingRoutes.map((route) => route.toJson()).toList();
        await prefs.setString(_routesKey, jsonEncode(routesJsonList));

        String message = 'Imported $addedCount routes';
        if (skippedCount > 0) {
          message += ' ($skippedCount skipped as duplicates)';
        }

        return ImportResult(success: true, message: message, importedCount: addedCount, skippedCount: skippedCount);
      }
    } catch (e) {
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }
}

/// Import işleminin sonucunu temsil eden sınıf
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final int skippedCount;

  ImportResult({required this.success, required this.message, this.importedCount = 0, this.skippedCount = 0});
}
