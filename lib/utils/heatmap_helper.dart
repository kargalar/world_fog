import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Sıcaklık haritası (heatmap) yardımcı sınıfı
class HeatmapHelper {
  /// Kalıcı sis bulutu efekti için daireler oluştur - Organik sis görünümü
  static List<CircleMarker> createHeatmapCircles(List<LatLng> areas, double radius, double opacity, {Color baseColor = Colors.blue}) {
    List<CircleMarker> circles = [];

    // Her keşfedilen alan için organik sis bulutu oluştur
    for (final area in areas) {
      // Çoklu katmanlı sis efekti - farklı boyutlarda daireler
      _addFogLayers(circles, area, radius, baseColor, opacity);
    }

    return circles;
  }

  /// Organik sis bulutu katmanları ekle
  static void _addFogLayers(List<CircleMarker> circles, LatLng center, double radius, Color baseColor, double opacity) {
    // Ana sis katmanı - en büyük, en şeffaf
    circles.add(
      CircleMarker(
        point: center,
        radius: radius * 1.2,
        useRadiusInMeter: true,
        color: baseColor.withValues(alpha: opacity * 0.15),
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ),
    );

    // Orta katman - orta boyut, orta şeffaflık
    circles.add(
      CircleMarker(
        point: center,
        radius: radius * 0.8,
        useRadiusInMeter: true,
        color: baseColor.withValues(alpha: opacity * 0.25),
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ),
    );

    // İç katman - küçük, daha yoğun
    circles.add(
      CircleMarker(
        point: center,
        radius: radius * 0.5,
        useRadiusInMeter: true,
        color: baseColor.withValues(alpha: opacity * 0.35),
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ),
    );

    // Merkez nokta - en küçük, en yoğun
    circles.add(
      CircleMarker(
        point: center,
        radius: radius * 0.25,
        useRadiusInMeter: true,
        color: baseColor.withValues(alpha: opacity * 0.45),
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ),
    );

    // Organik görünüm için rastgele offset'li ek katmanlar
    _addOrganicLayers(circles, center, radius, baseColor, opacity);
  }

  /// Organik sis görünümü için rastgele offset'li katmanlar
  static void _addOrganicLayers(List<CircleMarker> circles, LatLng center, double radius, Color baseColor, double opacity) {
    // Küçük offset'lerle ek sis parçacıkları
    final offsets = [
      [0.0003, 0.0002], // Kuzeydoğu
      [-0.0002, 0.0003], // Kuzeybatı
      [0.0002, -0.0002], // Güneydoğu
      [-0.0003, -0.0001], // Güneybatı
    ];

    for (final offset in offsets) {
      final offsetPoint = LatLng(center.latitude + offset[0], center.longitude + offset[1]);

      // Küçük sis parçacıkları
      circles.add(
        CircleMarker(
          point: offsetPoint,
          radius: radius * 0.4,
          useRadiusInMeter: true,
          color: baseColor.withValues(alpha: opacity * 0.2),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      circles.add(
        CircleMarker(
          point: offsetPoint,
          radius: radius * 0.2,
          useRadiusInMeter: true,
          color: baseColor.withValues(alpha: opacity * 0.3),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }
  }
}
