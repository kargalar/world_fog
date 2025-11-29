import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/route_model.dart';
import '../utils/app_strings.dart';

class RouteDetailPage extends StatefulWidget {
  final RouteModel route;

  const RouteDetailPage({super.key, required this.route});

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  bool _isSimulating = false;
  bool _isPaused = false;
  int _currentPointIndex = 0;
  Timer? _simulationTimer;
  DateTime? _currentSimulationTime;
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  bool _isSliderControlling = false;
  double _sliderValue = 0.0;

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    if (widget.route.routePoints.isEmpty) return;

    setState(() {
      _isSimulating = true;
      _isPaused = false;
      if (_currentPointIndex == 0) {
        _currentPointIndex = 0;
      }
    });

    final startTime = widget.route.startTime;
    _currentSimulationTime = startTime;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_currentPointIndex < widget.route.routePoints.length - 1 && !_isSliderControlling && !_isPaused) {
        setState(() {
          _currentPointIndex++;
          _sliderValue = _currentPointIndex / (widget.route.routePoints.length - 1);

          final totalDuration = widget.route.endTime != null ? widget.route.endTime!.difference(widget.route.startTime).inSeconds : 3600;
          final progress = _currentPointIndex / (widget.route.routePoints.length - 1);
          final elapsedSeconds = (totalDuration * progress).round();
          _currentSimulationTime = startTime.add(Duration(seconds: elapsedSeconds));
        });

        if (_mapController.isCompleted) {
          final controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newLatLng(widget.route.routePoints[_currentPointIndex].position));
        }
      } else if (!_isSliderControlling && _currentPointIndex >= widget.route.routePoints.length - 1) {
        _stopSimulation();
      }
    });
  }

  void _pauseSimulation() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeSimulation() {
    setState(() {
      _isPaused = false;
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _isPaused = false;
      _sliderValue = 0.0;
      _currentPointIndex = 0;
      _currentSimulationTime = null;
    });
  }

  void _onSliderChanged(double value) async {
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
    });

    if (_currentPointIndex < widget.route.routePoints.length && _mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(widget.route.routePoints[_currentPointIndex].position));
    }
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

  bool get _hasElevationData {
    return widget.route.routePoints.any((point) => point.altitude > 0);
  }

  // Toplam çıkış mesafesini hesapla
  double get _totalAscent {
    if (!_hasElevationData || widget.route.routePoints.length < 2) return 0.0;

    double ascent = 0.0;
    for (int i = 1; i < widget.route.routePoints.length; i++) {
      final prevAltitude = widget.route.routePoints[i - 1].altitude;
      final currentAltitude = widget.route.routePoints[i].altitude;
      if (currentAltitude > prevAltitude) {
        ascent += (currentAltitude - prevAltitude);
      }
    }
    return ascent;
  }

  // Toplam iniş mesafesini hesapla
  double get _totalDescent {
    if (!_hasElevationData || widget.route.routePoints.length < 2) return 0.0;

    double descent = 0.0;
    for (int i = 1; i < widget.route.routePoints.length; i++) {
      final prevAltitude = widget.route.routePoints[i - 1].altitude;
      final currentAltitude = widget.route.routePoints[i].altitude;
      if (currentAltitude < prevAltitude) {
        descent += (prevAltitude - currentAltitude);
      }
    }
    return descent;
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

    // Mevcut pozisyonun yüksekliğini ve mesafesini hesapla
    double currentDistance = 0;
    double currentAltitude = 0;
    if (_currentPointIndex < widget.route.routePoints.length) {
      currentAltitude = widget.route.routePoints[_currentPointIndex].altitude;
      for (int i = 0; i < _currentPointIndex; i++) {
        if (i > 0) {
          final prevPoint = widget.route.routePoints[i - 1];
          final currentPoint = widget.route.routePoints[i];
          currentDistance += Geolocator.distanceBetween(prevPoint.position.latitude, prevPoint.position.longitude, currentPoint.position.latitude, currentPoint.position.longitude);
        }
      }
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terrain, color: Colors.brown, size: 12),
              const SizedBox(width: 4),
              Text('${AppStrings.elevation} ${minAltitude.toStringAsFixed(0)}-${maxAltitude.toStringAsFixed(0)}m', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (_currentPointIndex >= 0 && _currentPointIndex < widget.route.routePoints.length) ...[
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
          // İniş ve çıkış bilgisi
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
                    barWidth: 1,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: Colors.brown.withAlpha(30)),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: minAltitude - (altitudeRange * 0.1),
                maxY: maxAltitude + (altitudeRange * 0.1),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    // Mevcut pozisyon için dikey çizgi
                    if (_currentPointIndex >= 0 && _currentPointIndex < widget.route.routePoints.length) VerticalLine(x: currentDistance / 1000, color: Colors.orange, strokeWidth: 2, dashArray: [5, 5]),
                  ],
                ),
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
            color: Colors.orange.withAlpha(26),
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
                // İniş/Çıkış bilgileri (sadece yükseklik verisi varsa)
                if (_hasElevationData) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildCompactInfo('↗ ${_totalAscent.toStringAsFixed(0)}m', Icons.trending_up, Colors.green), _buildCompactInfo('↘ ${_totalDescent.toStringAsFixed(0)}m', Icons.trending_down, Colors.red)]),
                ],
                // Simülasyon kontrolü
                if (widget.route.routePoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Simülasyon butonları
                      if (!_isSimulating)
                        IconButton(onPressed: _startSimulation, icon: const Icon(Icons.play_arrow), color: Colors.green, iconSize: 20)
                      else if (_isPaused)
                        IconButton(onPressed: _resumeSimulation, icon: const Icon(Icons.play_arrow), color: Colors.green, iconSize: 20)
                      else
                        IconButton(onPressed: _pauseSimulation, icon: const Icon(Icons.pause), color: Colors.orange, iconSize: 20),

                      IconButton(onPressed: _isSimulating ? _stopSimulation : null, icon: const Icon(Icons.stop), color: Colors.red, iconSize: 20),
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
                              inactiveColor: Colors.orange.withAlpha(150),
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
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: widget.route.routePoints.isNotEmpty ? widget.route.routePoints.first.position : const LatLng(0, 0), zoom: 15.0),
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(5.0, 18.0),
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              polygons: _buildHeatmapPolygons(),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.route.routePoints.isEmpty) return markers;

    // Başlangıç noktası
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: widget.route.routePoints.first.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Başlangıç'),
      ),
    );

    // Bitiş noktası
    if (widget.route.routePoints.length > 1) {
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: widget.route.routePoints.last.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Bitiş'),
        ),
      );
    }

    // Mevcut pozisyon markeri - simülasyon sırasında VEYA slider hareket ettirildiğinde göster
    if ((_isSimulating || _sliderValue > 0) && _currentPointIndex < widget.route.routePoints.length) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: widget.route.routePoints[_currentPointIndex].position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Mevcut Konum'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (widget.route.routePoints.isEmpty) return polylines;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Tüm rota çizgisi
    polylines.add(Polyline(polylineId: const PolylineId('route'), points: widget.route.routePoints.map((p) => p.position).toList(), color: isDarkMode ? Colors.lightBlue.withAlpha(128) : Colors.blue.withAlpha(128), width: 3));

    // Tamamlanmış rota bölümü - simülasyon sırasında VEYA slider hareket ettirildiğinde göster
    if ((_isSimulating || _sliderValue > 0) && _currentPointIndex > 0) {
      polylines.add(Polyline(polylineId: const PolylineId('completed'), points: widget.route.routePoints.sublist(0, _currentPointIndex + 1).map((p) => p.position).toList(), color: Colors.orange, width: 5));
    }

    return polylines;
  }

  Set<Polygon> _buildHeatmapPolygons() {
    final polygons = <Polygon>{};

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

      polygons.add(Polygon(polygonId: PolygonId('heatmap_$i'), points: polygonPoints, fillColor: color.withAlpha(80), strokeColor: color.withAlpha(100), strokeWidth: 1));
    }

    return polygons;
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
}
