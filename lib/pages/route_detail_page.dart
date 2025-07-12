import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/route_model.dart';
import 'dart:async';

class RouteDetailPage extends StatefulWidget {
  final RouteModel route;

  const RouteDetailPage({super.key, required this.route});

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  bool _isSimulating = false;
  int _currentPointIndex = 0;
  Timer? _simulationTimer;
  DateTime? _currentSimulationTime;
  late MapController _mapController;
  bool _isSliderControlling = false;
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    if (widget.route.routePoints.isEmpty) return;

    setState(() {
      _isSimulating = true;
      _currentPointIndex = 0;
    });

    final startTime = widget.route.startTime;
    _currentSimulationTime = startTime;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentPointIndex < widget.route.routePoints.length - 1 && !_isSliderControlling) {
        setState(() {
          _currentPointIndex++;
          _sliderValue = _currentPointIndex / (widget.route.routePoints.length - 1);

          final totalDuration = widget.route.endTime != null ? widget.route.endTime!.difference(widget.route.startTime).inSeconds : 3600;
          final progress = _currentPointIndex / (widget.route.routePoints.length - 1);
          final elapsedSeconds = (totalDuration * progress).round();
          _currentSimulationTime = startTime.add(Duration(seconds: elapsedSeconds));
        });

        _mapController.move(widget.route.routePoints[_currentPointIndex].position, _mapController.camera.zoom);
      } else if (!_isSliderControlling) {
        _stopSimulation();
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _sliderValue = 0.0;
      _currentPointIndex = 0;
      _currentSimulationTime = null;
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
      _isSliderControlling = true;

      final maxIndex = widget.route.routePoints.length - 1;
      _currentPointIndex = (value * maxIndex).round();

      if (widget.route.routePoints.isNotEmpty) {
        final startTime = widget.route.startTime;
        final totalDuration = widget.route.totalDuration;
        final elapsedSeconds = (totalDuration.inSeconds * value).round();
        _currentSimulationTime = startTime.add(Duration(seconds: elapsedSeconds));
      }

      if (_currentPointIndex < widget.route.routePoints.length) {
        _mapController.move(widget.route.routePoints[_currentPointIndex].position, _mapController.camera.zoom);
      }
    });
  }

  void _onSliderChangeStart(double value) {
    setState(() {
      _isSliderControlling = true;
    });
    _simulationTimer?.cancel();
  }

  void _onSliderChangeEnd(double value) {
    setState(() {
      _isSliderControlling = false;
    });
    if (_isSimulating) {
      _startSimulation();
    }
  }

  void _resetSimulation() {
    _stopSimulation();
    setState(() {
      _sliderValue = 0.0;
      _currentPointIndex = 0;
      _currentSimulationTime = null;
    });
  }

  bool get _hasElevationData {
    return widget.route.routePoints.any((point) => point.altitude > 0);
  }

  Widget _buildElevationChart() {
    if (!_hasElevationData) {
      return const SizedBox.shrink();
    }

    final points = <FlSpot>[];
    double distance = 0;

    for (int i = 0; i < widget.route.routePoints.length; i++) {
      if (i > 0) {
        final prevPoint = widget.route.routePoints[i - 1];
        final currentPoint = widget.route.routePoints[i];
        distance += Geolocator.distanceBetween(prevPoint.position.latitude, prevPoint.position.longitude, currentPoint.position.latitude, currentPoint.position.longitude);
      }
      points.add(FlSpot(distance / 1000, widget.route.routePoints[i].altitude));
    }

    final minAltitude = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxAltitude = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    final altitudeRange = maxAltitude - minAltitude;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terrain, color: Colors.brown, size: 12),
              const SizedBox(width: 4),
              Text('Yükseklik: ${minAltitude.toStringAsFixed(0)}-${maxAltitude.toStringAsFixed(0)}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
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
                    barWidth: 1,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: Colors.brown.withOpacity(0.1)),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: minAltitude - (altitudeRange * 0.1),
                maxY: maxAltitude + (altitudeRange * 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.route.name), backgroundColor: Theme.of(context).colorScheme.inversePrimary, toolbarHeight: 48),
      body: Column(
        children: [
          // Minimal kontrol paneli
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.withOpacity(0.1),
            child: Column(
              children: [
                // Temel bilgiler tek satırda
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactInfo(widget.route.formattedDistance, Icons.straighten, Colors.blue),
                    _buildCompactInfo(widget.route.formattedDuration, Icons.timer, Colors.green),
                    if (widget.route.totalBreakTime.inSeconds > 0) _buildCompactInfo(widget.route.formattedBreakTime, Icons.coffee, Colors.brown),
                    _buildCompactInfo('${widget.route.exploredAreas.length}', Icons.location_on, Colors.orange),
                  ],
                ),
                // Simülasyon kontrolü
                if (widget.route.routePoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Simülasyon butonları
                      IconButton(onPressed: _isSimulating ? null : _startSimulation, icon: const Icon(Icons.play_arrow), color: Colors.green, iconSize: 20),
                      IconButton(onPressed: _isSimulating ? _stopSimulation : null, icon: const Icon(Icons.pause), color: Colors.orange, iconSize: 20),
                      IconButton(onPressed: (_isSimulating || _currentPointIndex > 0) ? _resetSimulation : null, icon: const Icon(Icons.refresh), color: Colors.red, iconSize: 20),
                      const SizedBox(width: 8),
                      // Slider
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _sliderValue,
                              min: 0.0,
                              max: 1.0,
                              divisions: widget.route.routePoints.length > 1 ? widget.route.routePoints.length - 1 : null,
                              activeColor: Colors.orange,
                              inactiveColor: Colors.orange.withOpacity(0.3),
                              onChanged: _onSliderChanged,
                              onChangeStart: _onSliderChangeStart,
                              onChangeEnd: _onSliderChangeEnd,
                            ),
                            if (_currentSimulationTime != null) Text(_formatTime(_currentSimulationTime!), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Yükseklik grafiği (sadece varsa)
          _buildElevationChart(),
          // Harita - Ana alan
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: widget.route.routePoints.isNotEmpty ? widget.route.routePoints.first.position : const LatLng(0, 0), initialZoom: 15.0, minZoom: 5.0, maxZoom: 18.0),
              children: [
                TileLayer(
                  urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.world_fog',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                // Keşfedilen alanlar
                if (widget.route.exploredAreas.isNotEmpty) PolygonLayer(polygons: _createHeatmapPolygons()),
                // Rota çizgisi
                if (widget.route.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: widget.route.routePoints.map((p) => p.position).toList(), color: Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue.withOpacity(0.5) : Colors.blue.withOpacity(0.5), strokeWidth: 3.0),
                      if (_isSimulating && _currentPointIndex > 0) Polyline(points: widget.route.routePoints.sublist(0, _currentPointIndex + 1).map((p) => p.position).toList(), color: Colors.orange, strokeWidth: 5.0),
                    ],
                  ),
                // Başlangıç ve bitiş noktaları
                if (widget.route.routePoints.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.route.routePoints.first.position,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        ),
                      ),
                      if (widget.route.routePoints.length > 1)
                        Marker(
                          point: widget.route.routePoints.last.position,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.stop, color: Colors.white, size: 16),
                          ),
                        ),
                      if (_isSimulating && _currentPointIndex < widget.route.routePoints.length)
                        Marker(
                          point: widget.route.routePoints[_currentPointIndex].position,
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getColorForFrequency(int frequency) {
    final clampedFreq = frequency.clamp(0, 10);
    final colors = [Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.yellow, Colors.orange, Colors.deepOrange, Colors.red];
    return colors[clampedFreq];
  }

  List<LatLng> _createHexagonPoints(LatLng center, double radius) {
    final points = <LatLng>[];
    const double metersPerDegree = 111320;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (math.pi / 180);
      final dx = radius * math.cos(angle) / metersPerDegree;
      final dy = radius * math.sin(angle) / metersPerDegree;

      points.add(LatLng(center.latitude + dy, center.longitude + dx / math.cos(center.latitude * math.pi / 180)));
    }

    return points;
  }

  List<Polygon> _createHeatmapPolygons() {
    final polygons = <Polygon>[];

    for (int i = 0; i < widget.route.exploredAreas.length; i++) {
      final area = widget.route.exploredAreas[i];

      int frequency = 0;
      for (final otherArea in widget.route.exploredAreas) {
        if (area != otherArea) {
          final distance = Geolocator.distanceBetween(area.latitude, area.longitude, otherArea.latitude, otherArea.longitude);
          if (distance < 60) {
            frequency++;
          }
        }
      }

      final color = _getColorForFrequency(frequency);
      final polygonPoints = _createHexagonPoints(area, 30.0);

      polygons.add(Polygon(points: polygonPoints, color: color.withOpacity(0.4), borderColor: color.withOpacity(0.6), borderStrokeWidth: 1));
    }

    return polygons;
  }
}
