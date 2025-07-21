import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// Organik sis şekli için path oluştur
  ui.Path _createOrganicFogPath(Offset center, double radius) {
    final path = ui.Path();
    final random = math.Random(center.dx.toInt() + center.dy.toInt()); // Sabit seed

    // Organik şekil için rastgele noktalar
    final points = <Offset>[];
    const numPoints = 12; // Daha az nokta = daha yumuşak şekil

    for (int i = 0; i < numPoints; i++) {
      final angle = (i * 2 * math.pi) / numPoints;

      // Rastgele radius varyasyonu (daha organik görünüm)
      final radiusVariation = 0.7 + (random.nextDouble() * 0.6); // 0.7 - 1.3 arası
      final currentRadius = radius * radiusVariation;

      // Rastgele açı varyasyonu
      final angleVariation = (random.nextDouble() - 0.5) * 0.3; // ±0.15 radyan
      final currentAngle = angle + angleVariation;

      final x = center.dx + math.cos(currentAngle) * currentRadius;
      final y = center.dy + math.sin(currentAngle) * currentRadius;

      points.add(Offset(x, y));
    }

    // Yumuşak eğriler ile organik şekil oluştur
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length; i++) {
        final current = points[i];
        final next = points[(i + 1) % points.length];
        final nextNext = points[(i + 2) % points.length];

        // Bezier eğrisi için kontrol noktaları
        final controlPoint1 = Offset(current.dx + (next.dx - current.dx) * 0.3, current.dy + (next.dy - current.dy) * 0.3);
        final controlPoint2 = Offset(next.dx - (nextNext.dx - next.dx) * 0.3, next.dy - (nextNext.dy - next.dy) * 0.3);

        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, next.dx, next.dy);
      }

      path.close();
    }

    return path;
  }

  /// Ek duman parçacıkları çiz
  void _drawFogParticles(Canvas canvas, Offset center, double radius) {
    final random = math.Random(center.dx.toInt() * 2 + center.dy.toInt());

    // Küçük duman parçacıkları - daha fazla parçacık
    for (int i = 0; i < 12; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = radius * (0.5 + random.nextDouble() * 0.8);
      final particleRadius = radius * (0.1 + random.nextDouble() * 0.2);

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final particleGradient = RadialGradient(
        colors: [
          baseColor.withValues(alpha: opacity * 0.7), // Parçacıklar daha görünür
          baseColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      );

      final particlePaint = Paint()
        ..shader = particleGradient.createShader(Rect.fromCircle(center: Offset(x, y), radius: particleRadius))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), particleRadius, particlePaint);
    }
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
