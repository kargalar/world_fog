import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Grid tabanlı keşfedilen alanları çizen widget
class GridPainterWidget extends StatelessWidget {
  final Set<String> exploredGrids;
  final double gridSizeDegrees;
  final MapController mapController;

  const GridPainterWidget({super.key, required this.exploredGrids, required this.gridSizeDegrees, required this.mapController});

  @override
  Widget build(BuildContext context) {
    if (exploredGrids.isEmpty) return const SizedBox.shrink();

    final polygons = _buildGridPolygons();

    return PolygonLayer(polygons: polygons);
  }

  List<Polygon> _buildGridPolygons() {
    final polygons = <Polygon>[];

    for (final gridKey in exploredGrids) {
      final bounds = _gridKeyToBounds(gridKey);
      if (bounds != null) {
        polygons.add(Polygon(points: [bounds.northWest, bounds.northEast, bounds.southEast, bounds.southWest], color: Colors.blue.withValues(alpha: 0.2)));
      }
    }

    return polygons;
  }

  /// Grid anahtarından LatLngBounds hesapla
  LatLngBounds? _gridKeyToBounds(String gridKey) {
    final parts = gridKey.split('_');
    if (parts.length != 2) return null;

    try {
      final latGrid = int.parse(parts[0]);
      final lngGrid = int.parse(parts[1]);

      final minLat = latGrid * gridSizeDegrees;
      final maxLat = (latGrid + 1) * gridSizeDegrees;
      final minLng = lngGrid * gridSizeDegrees;
      final maxLng = (lngGrid + 1) * gridSizeDegrees;

      return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    } catch (e) {
      return null;
    }
  }
}
