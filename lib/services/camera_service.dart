import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Kamera ve fotoğraf işlemlerini yöneten servis sınıfı
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  /// Fotoğrafları kaydedeceğimiz dizini al
  Future<Directory> getPhotoDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${appDir.path}/route_photos');

    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    return photoDir;
  }

  /// Fotoğrafı uygulama dizinine kaydet
  Future<String?> savePhoto(String sourcePath) async {
    try {
      final photoDir = await getPhotoDirectory();
      final fileName = 'waypoint_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = '${photoDir.path}/$fileName';

      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(destinationPath);
        debugPrint('📸 Fotoğraf kaydedildi: $destinationPath');
        return destinationPath;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Fotoğraf kaydedilemedi: $e');
      return null;
    }
  }

  /// Fotoğrafı sil
  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Fotoğraf silindi: $photoPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Fotoğraf silinemedi: $e');
      return false;
    }
  }

  /// Tüm fotoğrafları temizle
  Future<void> clearAllPhotos() async {
    try {
      final photoDir = await getPhotoDirectory();
      if (await photoDir.exists()) {
        await photoDir.delete(recursive: true);
        debugPrint('🗑️ Tüm fotoğraflar silindi');
      }
    } catch (e) {
      debugPrint('❌ Fotoğraflar temizlenemedi: $e');
    }
  }
}
