import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

    // Her 0.5 saniyede bir simülasyonu ilerlet
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentPointIndex < widget.route.routePoints.length - 1) {
        setState(() {
          _currentPointIndex++;
          // Simülasyon süresini hesapla
          final totalDuration = widget.route.endTime != null ? widget.route.endTime!.difference(widget.route.startTime).inSeconds : 3600; // 1 saat default
          final progress = _currentPointIndex / (widget.route.routePoints.length - 1);
          final elapsedSeconds = (totalDuration * progress).round();
          _currentSimulationTime = startTime.add(Duration(seconds: elapsedSeconds));
        });

        // Haritayı mevcut noktaya odakla
        _mapController.move(widget.route.routePoints[_currentPointIndex], _mapController.camera.zoom);
      } else {
        _stopSimulation();
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _currentPointIndex = 0;
      _currentSimulationTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.route.name), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: Column(
        children: [
          // Simülasyon kontrol paneli
          if (_isSimulating || _currentSimulationTime != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withOpacity(0.1),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Simülasyon Aktif',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                  if (_currentSimulationTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Zaman: ${_formatTime(_currentSimulationTime!)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                      ),
                    ),
                ],
              ),
            ),
          // Simülasyon butonları
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSimulating ? null : _startSimulation,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Simülasyonu Başlat'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _isSimulating ? _stopSimulation : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Simülasyonu Durdur'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          // Rota bilgileri
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoCard('Mesafe', widget.route.formattedDistance, Icons.straighten, Colors.blue),
                    _buildInfoCard('Süre', widget.route.formattedDuration, Icons.timer, Colors.green),
                    _buildInfoCard('Keşif Alanı', '${widget.route.exploredAreas.length}', Icons.location_on, Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [_buildInfoCard('Başlangıç', _formatTimeShort(widget.route.startTime), Icons.play_arrow, Colors.green), _buildInfoCard('Bitiş', widget.route.endTime != null ? _formatTimeShort(widget.route.endTime!) : 'Devam ediyor', Icons.stop, Colors.red)],
                ),
              ],
            ),
          ),
          // Harita
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: widget.route.routePoints.isNotEmpty ? widget.route.routePoints.first : const LatLng(0, 0), initialZoom: 15.0, minZoom: 5.0, maxZoom: 18.0),
              children: [
                TileLayer(
                  urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.world_fog',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                // Keşfedilen alanlar
                if (widget.route.exploredAreas.isNotEmpty)
                  CircleLayer(
                    circles: widget.route.exploredAreas.map((area) {
                      // Çevresindeki diğer alanları say (frekans hesabı)
                      int nearbyCount = 0;
                      for (final otherArea in widget.route.exploredAreas) {
                        if (area != otherArea) {
                          final distance = Geolocator.distanceBetween(area.latitude, area.longitude, otherArea.latitude, otherArea.longitude);
                          if (distance < 45) {
                            // 30m yarıçapının 1.5 katı
                            nearbyCount++;
                          }
                        }
                      }

                      // Frekansa göre renk belirleme
                      final areaColor = _getColorForFrequency(nearbyCount);

                      return CircleMarker(
                        point: area,
                        radius: 30.0,
                        useRadiusInMeter: true,
                        color: areaColor.withOpacity(0.4), // Sabit opacity
                        borderStrokeWidth: 0,
                      );
                    }).toList(),
                  ),
                // Rota çizgisi
                if (widget.route.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      // Tüm rota
                      Polyline(points: widget.route.routePoints, color: Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue.withOpacity(0.5) : Colors.blue.withOpacity(0.5), strokeWidth: 3.0),
                      // Simülasyon sırasında geçilen kısım
                      if (_isSimulating && _currentPointIndex > 0) Polyline(points: widget.route.routePoints.sublist(0, _currentPointIndex + 1), color: Colors.orange, strokeWidth: 5.0),
                    ],
                  ),
                // Başlangıç ve bitiş noktaları
                if (widget.route.routePoints.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      // Başlangıç noktası
                      Marker(
                        point: widget.route.routePoints.first,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        ),
                      ),
                      // Bitiş noktası
                      if (widget.route.routePoints.length > 1)
                        Marker(
                          point: widget.route.routePoints.last,
                          width: 30,
                          height: 30,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.stop, color: Colors.white, size: 20),
                          ),
                        ),
                      // Simülasyon sırasında mevcut konum
                      if (_isSimulating && _currentPointIndex < widget.route.routePoints.length)
                        Marker(
                          point: widget.route.routePoints[_currentPointIndex],
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.navigation, color: Colors.white, size: 25),
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

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatTimeShort(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getColorForFrequency(int frequency) {
    // Frekansı 0-10 arasında sınırla
    final clampedFreq = frequency.clamp(0, 10);

    // Gradient renk paleti: Mavi (az) -> Yeşil -> Sarı -> Turuncu -> Kırmızı (çok)
    final colors = [
      Colors.blue, // 0-1 kez
      Colors.lightBlue, // 2 kez
      Colors.cyan, // 3 kez
      Colors.teal, // 4 kez
      Colors.green, // 5 kez
      Colors.lightGreen, // 6 kez
      Colors.yellow, // 7 kez
      Colors.orange, // 8 kez
      Colors.deepOrange, // 9 kez
      Colors.red, // 10+ kez
    ];

    return colors[clampedFreq];
  }
}
