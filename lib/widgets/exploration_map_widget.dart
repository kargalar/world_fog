import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

class ExplorationMapWidget extends StatelessWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final List<LatLng> exploredAreas;
  final List<RoutePoint> currentRoutePoints;
  final List<LatLng> currentRouteExploredAreas;
  final List<RouteModel> pastRoutes;
  final bool showPastRoutes;
  final double explorationRadius;
  final double areaOpacity;
  final bool isFollowingLocation;
  final double? currentBearing;

  const ExplorationMapWidget({
    super.key,
    required this.mapController,
    this.currentPosition,
    required this.exploredAreas,
    required this.currentRoutePoints,
    required this.currentRouteExploredAreas,
    required this.pastRoutes,
    required this.showPastRoutes,
    required this.explorationRadius,
    required this.areaOpacity,
    required this.isFollowingLocation,
    this.currentBearing,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: currentPosition ?? const LatLng(39.9334, 32.8597),
        initialZoom: 15.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.world_fog', maxZoom: 18),

        // Keşfedilen alanlar - Sis efekti (geçmiş)
        if (exploredAreas.isNotEmpty) CircleLayer(circles: _createFogCircles(exploredAreas, explorationRadius, Colors.blue.withValues(alpha: areaOpacity * 0.6))),

        // Aktif rota keşif alanları - Sis efekti
        if (currentRouteExploredAreas.isNotEmpty) CircleLayer(circles: _createFogCircles(currentRouteExploredAreas, explorationRadius, Colors.green.withValues(alpha: areaOpacity * 0.8))),

        // Geçmiş rotalar
        if (showPastRoutes && pastRoutes.isNotEmpty)
          PolylineLayer(
            polylines: pastRoutes.map((route) => Polyline(points: route.routePoints.map((point) => point.position).toList(), strokeWidth: 2.0, color: Colors.grey.withValues(alpha: 0.6))).toList(),
          ),

        // Aktif rota çizgisi
        if (currentRoutePoints.length > 1)
          PolylineLayer(
            polylines: [Polyline(points: currentRoutePoints.map((point) => point.position).toList(), strokeWidth: 4.0, color: Colors.red)],
          ),

        // Mevcut konum işaretçisi
        if (currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPosition!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: currentBearing != null
                      ? Transform.rotate(
                          angle: currentBearing! * (3.14159 / 180),
                          child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                        )
                      : const Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Sıcaklık haritası için daireler oluştur
  List<CircleMarker> _createFogCircles(List<LatLng> areas, double radius, Color baseColor) {
    List<CircleMarker> circles = [];

    // Alanları grid sistemine göre grupla ve sıklığa göre renk ver
    final Map<String, List<LatLng>> gridGroups = {};

    for (final area in areas) {
      final gridKey = _getGridKey(area, radius / 3);
      gridGroups[gridKey] ??= [];
      gridGroups[gridKey]!.add(area);
    }

    // Her grid için sıklığa göre renk hesapla
    for (final entry in gridGroups.entries) {
      final gridAreas = entry.value;
      final visitCount = gridAreas.length;

      // Sıcaklık haritası rengi hesapla
      final heatmapColor = _getHeatmapColor(visitCount);

      if (heatmapColor.a > 0) {
        // Grid merkezini hesapla
        final centerLat = gridAreas.map((a) => a.latitude).reduce((a, b) => a + b) / gridAreas.length;
        final centerLng = gridAreas.map((a) => a.longitude).reduce((a, b) => a + b) / gridAreas.length;
        final centerPoint = LatLng(centerLat, centerLng);

        // Sıklığa göre boyut hesapla
        final sizeMultiplier = (visitCount / 10.0).clamp(0.5, 3.0);

        // Ana sis dairesi
        circles.add(CircleMarker(point: centerPoint, radius: radius * sizeMultiplier, useRadiusInMeter: true, color: heatmapColor, borderColor: Colors.transparent, borderStrokeWidth: 0));

        // İç daire (daha yoğun)
        circles.add(
          CircleMarker(
            point: centerPoint,
            radius: radius * sizeMultiplier * 0.6,
            useRadiusInMeter: true,
            color: heatmapColor.withValues(alpha: heatmapColor.a * 1.3),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
          ),
        );

        // Merkez nokta (en yoğun)
        circles.add(
          CircleMarker(
            point: centerPoint,
            radius: radius * sizeMultiplier * 0.2,
            useRadiusInMeter: true,
            color: heatmapColor.withValues(alpha: heatmapColor.a * 1.8),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
          ),
        );
      }
    }

    return circles;
  }

  /// Pozisyonu grid anahtarına çevir
  String _getGridKey(LatLng position, double gridSize) {
    final latGrid = (position.latitude / gridSize).floor();
    final lngGrid = (position.longitude / gridSize).floor();
    return '${latGrid}_$lngGrid';
  }

  /// Ziyaret sıklığına göre sıcaklık haritası rengi hesapla
  Color _getHeatmapColor(int visitCount) {
    if (visitCount == 0) return Colors.transparent;

    // Sıcaklık haritası renkleri: Mavi -> Yeşil -> Sarı -> Kırmızı
    final intensity = (visitCount / 20.0).clamp(0.0, 1.0); // Max 20 ziyaret için normalize

    if (intensity < 0.25) {
      // Mavi -> Cyan
      return Color.lerp(Colors.blue.withValues(alpha: 0.4), Colors.cyan.withValues(alpha: 0.5), intensity * 4)!;
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
}
