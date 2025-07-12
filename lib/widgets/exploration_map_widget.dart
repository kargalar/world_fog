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

        // Keşfedilen alanlar (geçmiş)
        if (exploredAreas.isNotEmpty)
          CircleLayer(
            circles: exploredAreas.map((area) => CircleMarker(point: area, radius: explorationRadius, useRadiusInMeter: true, color: Colors.blue.withOpacity(areaOpacity), borderColor: Colors.blue.withOpacity(areaOpacity * 0.5), borderStrokeWidth: 1)).toList(),
          ),

        // Aktif rota keşif alanları
        if (currentRouteExploredAreas.isNotEmpty)
          CircleLayer(
            circles: currentRouteExploredAreas.map((area) => CircleMarker(point: area, radius: explorationRadius, useRadiusInMeter: true, color: Colors.green.withOpacity(areaOpacity), borderColor: Colors.green.withOpacity(areaOpacity * 0.5), borderStrokeWidth: 1)).toList(),
          ),

        // Geçmiş rotalar
        if (showPastRoutes && pastRoutes.isNotEmpty)
          PolylineLayer(
            polylines: pastRoutes.map((route) => Polyline(points: route.routePoints.map((point) => point.position).toList(), strokeWidth: 2.0, color: Colors.grey.withOpacity(0.6))).toList(),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
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
}
