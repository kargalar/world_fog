import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/route_model.dart';
import '../utils/app_strings.dart';
import '../widgets/waypoint_dialog.dart';
import '../utils/app_colors.dart';

/// Custom marker icons for route detail page
class _RouteMarkerIcons {
  static BitmapDescriptor? routeStart;
  static BitmapDescriptor? routeEnd;
  static BitmapDescriptor? currentPosition;
  static BitmapDescriptor? scenery;
  static BitmapDescriptor? fountain;
  static BitmapDescriptor? junction;
  static BitmapDescriptor? waterfall;
  static BitmapDescriptor? breakPoint;
  static BitmapDescriptor? other;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    routeStart = await _createCustomMarker(Icons.flag, AppColors.green, 45);
    routeEnd = await _createCustomMarker(Icons.flag_outlined, AppColors.red, 45);
    currentPosition = await _createCustomMarker(Icons.navigation, AppColors.orange, 40);
    scenery = await _createCustomMarker(Icons.landscape, AppColors.greenShade700, 40);
    fountain = await _createCustomMarker(Icons.water_drop, AppColors.blue, 40);
    junction = await _createCustomMarker(Icons.alt_route, AppColors.orange, 40);
    waterfall = await _createCustomMarker(Icons.water, AppColors.cyan, 40);
    breakPoint = await _createCustomMarker(Icons.coffee, AppColors.brown, 40);
    other = await _createCustomMarker(Icons.location_on, AppColors.purple, 40);

    _initialized = true;
  }

  static Future<BitmapDescriptor> _createCustomMarker(IconData icon, Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final double markerSize = size;
    final double iconSize = size * 0.55;

    // Draw shadow
    canvas.drawCircle(Offset(markerSize / 2 + 1, markerSize / 2 + 2), markerSize / 2 - 2, shadowPaint);

    // Draw circle background
    canvas.drawCircle(Offset(markerSize / 2, markerSize / 2), markerSize / 2 - 2, paint);

    // Draw white border
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(markerSize / 2, markerSize / 2), markerSize / 2 - 2, borderPaint);

    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontSize: iconSize, fontFamily: icon.fontFamily, package: icon.fontPackage, color: AppColors.white),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((markerSize - textPainter.width) / 2, (markerSize - textPainter.height) / 2));

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(markerSize.toInt(), markerSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static BitmapDescriptor getWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return scenery ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case WaypointType.fountain:
        return fountain ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case WaypointType.junction:
        return junction ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case WaypointType.waterfall:
        return waterfall ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      case WaypointType.breakPoint:
        return breakPoint ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case WaypointType.other:
        return other ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }
}

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
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  Future<void> _initializeMarkers() async {
    await _RouteMarkerIcons.initialize();
    if (mounted) setState(() {});
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
              const Icon(Icons.terrain, color: AppColors.brown, size: 12),
              const SizedBox(width: 4),
              Text('${AppStrings.elevation} ${minAltitude.toStringAsFixed(0)}-${maxAltitude.toStringAsFixed(0)}m', style: const TextStyle(fontSize: 10, color: AppColors.grey)),
              if (_currentPointIndex >= 0 && _currentPointIndex < widget.route.routePoints.length) ...[
                const SizedBox(width: 8),
                const Icon(Icons.height, color: AppColors.orange, size: 12),
                const SizedBox(width: 2),
                Text(
                  '${currentAltitude.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: AppColors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          // İniş ve çıkış bilgisi
          if (_hasElevationData) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.green, size: 12),
                const SizedBox(width: 2),
                Text(
                  '↗ ${_totalAscent.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.trending_down, color: AppColors.red, size: 12),
                const SizedBox(width: 2),
                Text(
                  '↘ ${_totalDescent.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 10, color: AppColors.red, fontWeight: FontWeight.bold),
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
                    color: AppColors.brown,
                    barWidth: 1,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: AppColors.brown.withAlpha(30)),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: minAltitude - (altitudeRange * 0.1),
                maxY: maxAltitude + (altitudeRange * 0.1),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    // Mevcut pozisyon için dikey çizgi
                    if (_currentPointIndex >= 0 && _currentPointIndex < widget.route.routePoints.length) VerticalLine(x: currentDistance / 1000, color: AppColors.orange, strokeWidth: 2, dashArray: [5, 5]),
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
            color: AppColors.orange.withAlpha(26),
            child: Column(
              children: [
                // Temel bilgiler tek satırda
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactInfo(widget.route.formattedDistance, Icons.straighten, AppColors.blue),
                    _buildCompactInfo(widget.route.formattedDuration, Icons.timer, AppColors.green),
                    _buildCompactInfo(widget.route.formattedAverageSpeed, Icons.speed, AppColors.purple),
                    if (widget.route.totalBreakTime.inSeconds > 0) _buildCompactInfo(widget.route.formattedBreakTime, Icons.coffee, AppColors.brown),
                    _buildCompactInfo('${widget.route.routePoints.length}', Icons.location_on, AppColors.orange),
                  ],
                ),
                // Hava durumu ve puan bilgisi
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.route.weather != null) ...[
                      Icon(_getWeatherIcon(widget.route.weather!.condition), size: 16, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(widget.route.weather!.conditionLabel + (widget.route.weather!.temperature != null ? ' ${widget.route.weather!.temperature!.toStringAsFixed(0)}°C' : ''), style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                    ] else ...[
                      const Icon(Icons.cloud_off, size: 16, color: AppColors.grey),
                      const SizedBox(width: 4),
                      const Text('No weather data', style: TextStyle(fontSize: 11, color: AppColors.grey)),
                    ],
                    const SizedBox(width: 12),
                    if (widget.route.rating != null) ...[
                      ...List.generate(widget.route.rating!, (index) => const Icon(Icons.star, size: 14, color: AppColors.amber)),
                      ...List.generate(5 - widget.route.rating!, (index) => const Icon(Icons.star_border, size: 14, color: AppColors.grey)),
                    ] else ...[
                      const Text('Not rated', style: TextStyle(fontSize: 11, color: AppColors.grey)),
                    ],
                  ],
                ),
                // İniş/Çıkış bilgileri (sadece yükseklik verisi varsa)
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [_buildCompactInfo(widget.route.formattedAscent, Icons.trending_up, AppColors.green), _buildCompactInfo(widget.route.formattedDescent, Icons.trending_down, AppColors.red), _buildCompactInfo('${widget.route.waypoints.length}', Icons.photo_camera, AppColors.deepPurple)],
                ),
                // Simülasyon kontrolü
                if (widget.route.routePoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Simülasyon butonları
                      if (!_isSimulating)
                        IconButton(onPressed: _startSimulation, icon: const Icon(Icons.play_arrow), color: AppColors.green, iconSize: 20)
                      else if (_isPaused)
                        IconButton(onPressed: _resumeSimulation, icon: const Icon(Icons.play_arrow), color: AppColors.green, iconSize: 20)
                      else
                        IconButton(onPressed: _pauseSimulation, icon: const Icon(Icons.pause), color: AppColors.orange, iconSize: 20),

                      IconButton(onPressed: _isSimulating ? _stopSimulation : null, icon: const Icon(Icons.stop), color: AppColors.red, iconSize: 20),
                      // Slider
                      Expanded(
                        child: Column(
                          children: [
                            Slider(
                              value: _sliderValue,
                              min: 0.0,
                              max: 1.0,
                              divisions: widget.route.routePoints.length > 1 ? widget.route.routePoints.length - 1 : null,
                              activeColor: AppColors.orange,
                              inactiveColor: AppColors.orange.withAlpha(150),
                              onChanged: _onSliderChanged,
                              onChangeStart: _onSliderChangeStart,
                              onChangeEnd: _onSliderChangeEnd,
                            ),
                            if (_currentSimulationTime != null) Text(_formatTime(_currentSimulationTime!), style: const TextStyle(fontSize: 10, color: AppColors.grey)),
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
        icon: _RouteMarkerIcons.routeStart ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Başlangıç'),
        anchor: const Offset(0.5, 0.5),
      ),
    );

    // Bitiş noktası
    if (widget.route.routePoints.length > 1) {
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: widget.route.routePoints.last.position,
          icon: _RouteMarkerIcons.routeEnd ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Bitiş'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    // Mevcut pozisyon markeri - simülasyon sırasında VEYA slider hareket ettirildiğinde göster
    if ((_isSimulating || _sliderValue > 0) && _currentPointIndex < widget.route.routePoints.length) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: widget.route.routePoints[_currentPointIndex].position,
          icon: _RouteMarkerIcons.currentPosition ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Mevcut Konum'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    // Waypoint markerları
    for (final waypoint in widget.route.waypoints) {
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_${waypoint.id}'),
          position: waypoint.position,
          icon: _RouteMarkerIcons.getWaypointIcon(waypoint.type),
          infoWindow: InfoWindow(title: waypoint.typeLabel),
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showWaypointDetail(waypoint),
        ),
      );
    }

    return markers;
  }

  void _showWaypointDetail(RouteWaypoint waypoint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => WaypointDetailSheet(waypoint: waypoint),
    );
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (widget.route.routePoints.isEmpty) return polylines;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Tüm rota çizgisi
    polylines.add(Polyline(polylineId: const PolylineId('route'), points: widget.route.routePoints.map((p) => p.position).toList(), color: isDarkMode ? AppColors.lightBlue.withAlpha(128) : AppColors.blue.withAlpha(128), width: 3));

    // Tamamlanmış rota bölümü - simülasyon sırasında VEYA slider hareket ettirildiğinde göster
    if ((_isSimulating || _sliderValue > 0) && _currentPointIndex > 0) {
      polylines.add(Polyline(polylineId: const PolylineId('completed'), points: widget.route.routePoints.sublist(0, _currentPointIndex + 1).map((p) => p.position).toList(), color: AppColors.orange, width: 5));
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

  IconData _getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rainy:
        return Icons.umbrella;
      case WeatherCondition.snowy:
        return Icons.ac_unit;
      case WeatherCondition.windy:
        return Icons.air;
      case WeatherCondition.foggy:
        return Icons.foggy;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getColorForFrequency(int frequency) {
    final clampedFreq = frequency.clamp(0, 10);
    final colors = [AppColors.blue, AppColors.lightBlue, AppColors.cyan, AppColors.teal, AppColors.green, AppColors.lightGreen, AppColors.yellow, AppColors.orange, AppColors.deepOrange, AppColors.red];
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
