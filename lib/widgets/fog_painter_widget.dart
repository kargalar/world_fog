import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Gerçek sis/duman efekti için özel çizim widget'ı
class FogPainterWidget extends StatelessWidget {
  final List<LatLng> exploredAreas;
  final double explorationRadius;
  final double opacity;
  final Color baseColor;
  final MapController mapController;

  const FogPainterWidget({super.key, required this.exploredAreas, required this.explorationRadius, required this.opacity, required this.baseColor, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FogEffectPainter(exploredAreas: exploredAreas, explorationRadius: explorationRadius, opacity: opacity, baseColor: baseColor, mapController: mapController),
      child: Container(),
    );
  }
}

/// Gerçek sis efekti çizen CustomPainter
class FogEffectPainter extends CustomPainter {
  final List<LatLng> exploredAreas;
  final double explorationRadius;
  final double opacity;
  final Color baseColor;
  final MapController mapController;

  FogEffectPainter({required this.exploredAreas, required this.explorationRadius, required this.opacity, required this.baseColor, required this.mapController});

  @override
  void paint(Canvas canvas, Size size) {
    if (exploredAreas.isEmpty) return;

    try {
      final camera = mapController.camera;

      // Her keşfedilen alan için organik sis bulutu çiz
      for (final area in exploredAreas) {
        _drawOrganicFog(canvas, size, camera, area);
      }
    } catch (e) {
      // MapController henüz hazır değilse çizim yapma
    }
  }

  /// Organik sis bulutu çiz
  void _drawOrganicFog(Canvas canvas, Size size, MapCamera camera, LatLng center) {
    // Koordinatları ekran koordinatlarına çevir
    // Doğru koordinat dönüşümü - Flutter Map'in kendi sistemini kullan

    // Web Mercator projection kullanarak doğru dönüşüm
    final mapBounds = camera.visibleBounds;
    final mapWidth = size.width;
    final mapHeight = size.height;

    // Longitude dönüşümü
    final lngRange = mapBounds.east - mapBounds.west;
    final x = ((center.longitude - mapBounds.west) / lngRange) * mapWidth;

    // Latitude dönüşümü (Mercator projection)
    final latRange = mapBounds.north - mapBounds.south;
    final y = ((mapBounds.north - center.latitude) / latRange) * mapHeight;

    final screenPoint = Offset(x, y);

    // Ekran sınırları içinde mi kontrol et
    // Radius'u metre cinsinden pixel'e çevir
    final metersPerPixel = (mapBounds.east - mapBounds.west) * 111320 / size.width; // Yaklaşık metre/pixel
    final screenRadius = explorationRadius / metersPerPixel; // Metre cinsinden radius'u pixel'e çevir
    if (screenPoint.dx < -screenRadius || screenPoint.dx > size.width + screenRadius || screenPoint.dy < -screenRadius || screenPoint.dy > size.height + screenRadius) {
      return;
    }

    // Stabil gradient sis efekti - çoklu katmanlı daireler
    _drawStableFogEffect(canvas, screenPoint, screenRadius, baseColor, opacity);
  }

  /// Stabil sis efekti çiz - hiç bozulmaz
  void _drawStableFogEffect(Canvas canvas, Offset center, double radius, Color baseColor, double opacity) {
    // Ana sis dairesi - en büyük katman
    final mainGradient = RadialGradient(
      colors: [
        baseColor.withValues(alpha: opacity * 0.8),
        baseColor.withValues(alpha: opacity * 0.5),
        baseColor.withValues(alpha: opacity * 0.2),
        baseColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );

    final mainPaint = Paint()
      ..shader = mainGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, mainPaint);

    // Orta katman - daha yoğun
    final midGradient = RadialGradient(
      colors: [
        baseColor.withValues(alpha: opacity * 1.0),
        baseColor.withValues(alpha: opacity * 0.6),
        baseColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final midPaint = Paint()
      ..shader = midGradient.createShader(Rect.fromCircle(center: center, radius: radius * 0.7))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.7, midPaint);

    // İç katman - en yoğun
    final innerGradient = RadialGradient(
      colors: [
        baseColor.withValues(alpha: opacity * 1.0),
        baseColor.withValues(alpha: opacity * 0.4),
        baseColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final innerPaint = Paint()
      ..shader = innerGradient.createShader(Rect.fromCircle(center: center, radius: radius * 0.4))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, innerPaint);

    // Merkez nokta - çok yoğun
    final centerPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.15, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Harita hareket ettiğinde yeniden çiz
  }
}
