import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
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

  /// Tüm rotaları ZIP dosyası olarak dışa aktarır (fotoğraflar dahil)
  static Future<String?> exportRoutes() async {
    try {
      final routes = await getSavedRoutes();
      if (routes.isEmpty) {
        return null;
      }

      // Fotoğrafları topla ve yeniden adlandır
      final Map<String, String> photoMapping = {}; // originalPath -> newName
      int photoIndex = 0;

      for (final route in routes) {
        for (final waypoint in route.waypoints) {
          if (waypoint.photoPath != null && waypoint.photoPath!.isNotEmpty) {
            final file = File(waypoint.photoPath!);
            if (await file.exists()) {
              final extension = waypoint.photoPath!.split('.').last;
              final newName = 'photos/photo_$photoIndex.$extension';
              photoMapping[waypoint.photoPath!] = newName;
              photoIndex++;
            }
          }
        }
      }

      // Export verisi için rotaları hazırla (fotoğraf yollarını güncelle)
      final exportRoutes = routes.map((route) {
        final routeJson = route.toJson();
        final updatedWaypoints = (routeJson['waypoints'] as List).map((w) {
          final waypointMap = Map<String, dynamic>.from(w as Map<String, dynamic>);
          if (waypointMap['photoPath'] != null && photoMapping.containsKey(waypointMap['photoPath'])) {
            waypointMap['photoPath'] = photoMapping[waypointMap['photoPath']];
          }
          return waypointMap;
        }).toList();
        routeJson['waypoints'] = updatedWaypoints;
        return routeJson;
      }).toList();

      final exportData = {'version': '1.1', 'exportDate': DateTime.now().toIso8601String(), 'routeCount': routes.length, 'photoCount': photoMapping.length, 'routes': exportRoutes};

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Archive oluştur
      final archive = Archive();

      // JSON dosyasını ekle
      final jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('routes.json', jsonBytes.length, jsonBytes));

      // Fotoğrafları ekle
      for (final entry in photoMapping.entries) {
        final file = File(entry.key);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(entry.value, bytes.length, bytes));
        }
      }

      // ZIP olarak encode et
      final zipData = ZipEncoder().encode(archive);

      // Geçici dosya oluştur
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/worldfog_routes_$timestamp.zip');
      await file.writeAsBytes(zipData);

      // Dosyayı paylaş
      await Share.shareXFiles([XFile(file.path)], subject: 'World Fog Routes Export');

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// ZIP veya JSON dosyasından rotaları içe aktarır
  static Future<ImportResult> importRoutes({bool replaceExisting = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'zip']);

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final filePath = result.files.single.path!;
      final isZip = filePath.toLowerCase().endsWith('.zip');

      Map<String, dynamic> importData;
      Map<String, String> extractedPhotos = {}; // archivePath -> localPath

      if (isZip) {
        // ZIP dosyasını işle
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // routes.json dosyasını bul
        final jsonFile = archive.files.firstWhere((f) => f.name == 'routes.json', orElse: () => throw Exception('routes.json not found in archive'));

        final jsonString = utf8.decode(jsonFile.content as List<int>);
        importData = jsonDecode(jsonString) as Map<String, dynamic>;

        // Fotoğrafları çıkar
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory('${appDir.path}/imported_photos');
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }

        for (final archiveFile in archive.files) {
          if (archiveFile.name.startsWith('photos/') && !archiveFile.isFile == false) {
            final fileName = archiveFile.name.split('/').last;
            final localPath = '${photosDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
            final outputFile = File(localPath);
            await outputFile.writeAsBytes(archiveFile.content as List<int>);
            extractedPhotos[archiveFile.name] = localPath;
          }
        }
      } else {
        // JSON dosyasını işle
        final file = File(filePath);
        final jsonString = await file.readAsString();
        importData = jsonDecode(jsonString) as Map<String, dynamic>;
      }

      // Versiyon kontrolü
      final version = importData['version'] as String?;
      if (version == null) {
        return ImportResult(success: false, message: 'Invalid file format');
      }

      final routesJson = importData['routes'] as List<dynamic>?;
      if (routesJson == null || routesJson.isEmpty) {
        return ImportResult(success: false, message: 'No routes found in file');
      }

      // Fotoğraf yollarını güncelle
      final updatedRoutesJson = routesJson.map((routeJson) {
        final routeMap = Map<String, dynamic>.from(routeJson as Map<String, dynamic>);
        if (routeMap['waypoints'] != null) {
          final updatedWaypoints = (routeMap['waypoints'] as List).map((w) {
            final waypointMap = Map<String, dynamic>.from(w as Map<String, dynamic>);
            if (waypointMap['photoPath'] != null && extractedPhotos.containsKey(waypointMap['photoPath'])) {
              waypointMap['photoPath'] = extractedPhotos[waypointMap['photoPath']];
            }
            return waypointMap;
          }).toList();
          routeMap['waypoints'] = updatedWaypoints;
        }
        return routeMap;
      }).toList();

      final importedRoutes = updatedRoutesJson.map((json) => RouteModel.fromJson(json)).toList();

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
