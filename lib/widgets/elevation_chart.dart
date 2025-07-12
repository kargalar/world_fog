import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';

class ElevationChart extends StatelessWidget {
  final List<RoutePoint> routePoints;
  final int currentPointIndex;
  final double height;

  const ElevationChart({super.key, required this.routePoints, required this.currentPointIndex, this.height = 80});

  bool get _hasElevationData {
    return routePoints.any((point) => point.altitude > 0);
  }

  double get _totalAscent {
    if (!_hasElevationData || routePoints.length < 2) return 0.0;

    double ascent = 0.0;
    for (int i = 1; i < routePoints.length; i++) {
      final prevAltitude = routePoints[i - 1].altitude;
      final currentAltitude = routePoints[i].altitude;
      if (currentAltitude > prevAltitude) {
        ascent += (currentAltitude - prevAltitude);
      }
    }
    return ascent;
  }

  double get _totalDescent {
    if (!_hasElevationData || routePoints.length < 2) return 0.0;

    double descent = 0.0;
    for (int i = 1; i < routePoints.length; i++) {
      final prevAltitude = routePoints[i - 1].altitude;
      final currentAltitude = routePoints[i].altitude;
      if (currentAltitude < prevAltitude) {
        descent += (prevAltitude - currentAltitude);
      }
    }
    return descent;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasElevationData || routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = <FlSpot>[];
    double distance = 0;

    for (int i = 0; i < routePoints.length; i++) {
      if (i > 0) {
        final prevPoint = routePoints[i - 1];
        final currentPoint = routePoints[i];
        distance += Geolocator.distanceBetween(prevPoint.position.latitude, prevPoint.position.longitude, currentPoint.position.latitude, currentPoint.position.longitude);
      }
      points.add(FlSpot(distance / 1000, routePoints[i].altitude));
    }

    final minAltitude = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxAltitude = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    // Mevcut pozisyonun yüksekliğini ve mesafesini hesapla
    double currentDistance = 0;
    double currentAltitude = 0;
    if (currentPointIndex < routePoints.length && currentPointIndex >= 0) {
      currentAltitude = routePoints[currentPointIndex].altitude;
      for (int i = 0; i < currentPointIndex; i++) {
        if (i > 0) {
          final prevPoint = routePoints[i - 1];
          final currentPoint = routePoints[i];
          currentDistance += Geolocator.distanceBetween(prevPoint.position.latitude, prevPoint.position.longitude, currentPoint.position.latitude, currentPoint.position.longitude);
        }
      }
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terrain, color: Colors.brown, size: 12),
              const SizedBox(width: 4),
              Text('Yükseklik: ${minAltitude.toStringAsFixed(0)}-${maxAltitude.toStringAsFixed(0)}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (currentPointIndex >= 0 && currentPointIndex < routePoints.length) ...[
                const SizedBox(width: 8),
                const Icon(Icons.height, color: Colors.orange, size: 12),
                const SizedBox(width: 2),
                Text(
                  '${currentAltitude.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          if (_hasElevationData) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green, size: 12),
                const SizedBox(width: 2),
                Text(
                  '↗ ${_totalAscent.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.trending_down, color: Colors.red, size: 12),
                const SizedBox(width: 2),
                Text(
                  '↘ ${_totalDescent.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    color: Colors.brown,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.brown.withOpacity(0.2)),
                  ),
                  // Mevcut pozisyon işaretçisi
                  if (currentPointIndex >= 0 && currentPointIndex < routePoints.length)
                    LineChartBarData(
                      spots: [FlSpot(currentDistance / 1000, currentAltitude)],
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(radius: 3, color: Colors.orange, strokeWidth: 2, strokeColor: Colors.white);
                        },
                      ),
                    ),
                ],
                minY: minAltitude - 10,
                maxY: maxAltitude + 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
