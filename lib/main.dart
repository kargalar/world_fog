import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'models/route_model.dart';
import 'services/route_service.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  void _updateTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World Fog - Keşif Haritası',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F), foregroundColor: Colors.white),
      ),
      themeMode: _themeMode,
      home: WorldFogPage(onThemeChanged: _updateTheme),
    );
  }
}

class WorldFogPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const WorldFogPage({super.key, required this.onThemeChanged});

  @override
  State<WorldFogPage> createState() => _WorldFogPageState();
}

class _WorldFogPageState extends State<WorldFogPage> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _exploredAreas = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  bool _isPaused = false;
  double _explorationRadius = 50.0; // Varsayılan 50 metre yarıçap (ayarlardan 1km'ye kadar çıkarılabilir)

  // Rota takibi için yeni değişkenler
  final List<LatLng> _currentRoutePoints = [];
  final List<LatLng> _currentRouteExploredAreas = [];
  DateTime? _routeStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPausedTime = Duration.zero;
  double _currentRouteDistance = 0.0;
  Duration _currentRouteDuration = Duration.zero;
  Timer? _durationTimer;

  // Geçmiş rotaları gösterme için değişkenler
  bool _showPastRoutes = false;
  List<RouteModel> _pastRoutes = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _startLocationTracking(); // Sürekli konum takibi
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _loadSettings();
    await _loadExploredAreas();
    await _getCurrentLocation();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final radius = prefs.getDouble('exploration_radius') ?? 50.0;
    setState(() {
      _explorationRadius = radius;
    });
  }

  Future<void> _requestPermissions() async {
    final locationPermission = await Permission.location.request();
    if (locationPermission.isDenied) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konum İzni Gerekli'),
        content: const Text('Uygulamanın çalışması için konum izni gereklidir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentPosition!, 15.0);
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
  }

  Future<void> _loadExploredAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final exploredData = prefs.getStringList('explored_areas') ?? [];

    setState(() {
      _exploredAreas = exploredData.map((data) {
        final coords = data.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList();
    });
  }

  Future<void> _saveExploredAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final exploredData = _exploredAreas.map((area) => '${area.latitude},${area.longitude}').toList();
    await prefs.setStringList('explored_areas', exploredData);
  }

  void _startTracking() {
    if (_isTracking) return;

    setState(() {
      _isTracking = true;
      _routeStartTime = DateTime.now();
      _currentRouteDistance = 0.0;
      _currentRouteDuration = Duration.zero;
      _totalPausedTime = Duration.zero;
      _currentRoutePoints.clear();
      _currentRouteExploredAreas.clear();

      // Başlangıç noktasını ekle
      if (_currentPosition != null) {
        _currentRoutePoints.add(_currentPosition!);
      }
    });

    // Süre sayacını başlat
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_routeStartTime != null && !_isPaused) {
        setState(() {
          final totalTime = DateTime.now().difference(_routeStartTime!);
          _currentRouteDuration = totalTime - _totalPausedTime;
        });
      }
    });
  }

  void _stopTracking() {
    _durationTimer?.cancel();

    // Rotayı kaydet
    if (_routeStartTime != null && _currentRoutePoints.isNotEmpty) {
      _showSaveRouteDialog();
    } else {
      setState(() {
        _isTracking = false;
        _isPaused = false;
      });
    }
  }

  void _showSaveRouteDialog() {
    final TextEditingController nameController = TextEditingController();
    final defaultName = 'Rota ${_formatDateTime(_routeStartTime!)}';
    nameController.text = defaultName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rotayı Kaydet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bu rotayı kaydetmek istediğinizden emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Rota Adı', border: OutlineInputBorder(), hintText: 'Rota için bir isim girin'),
              maxLength: 50,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_formatDistance(_currentRouteDistance)),
                const SizedBox(width: 16),
                Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_formatDuration(_currentRouteDuration)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isTracking = false;
                _isPaused = false;
              });
            },
            child: const Text('Kaydetme'),
          ),
          ElevatedButton(
            onPressed: () {
              final routeName = nameController.text.trim().isEmpty ? defaultName : nameController.text.trim();
              Navigator.pop(context);
              _saveCurrentRoute(routeName);
              setState(() {
                _isTracking = false;
                _isPaused = false;
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _pauseTracking() {
    _durationTimer?.cancel();

    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
    });
  }

  void _resumeTracking() {
    // Duraklatma süresini hesapla
    if (_pauseStartTime != null) {
      _totalPausedTime += DateTime.now().difference(_pauseStartTime!);
    }

    setState(() {
      _isPaused = false;
      _pauseStartTime = null;
    });

    // Süre sayacını yeniden başlat
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_routeStartTime != null && !_isPaused) {
        setState(() {
          final totalTime = DateTime.now().difference(_routeStartTime!);
          _currentRouteDuration = totalTime - _totalPausedTime;
        });
      }
    });
  }

  Future<void> _saveCurrentRoute([String? customName]) async {
    if (_routeStartTime == null || _currentRoutePoints.isEmpty) return;

    final routeId = DateTime.now().millisecondsSinceEpoch.toString();
    final routeName = customName ?? 'Rota ${_formatDateTime(_routeStartTime!)}';

    final route = RouteModel(id: routeId, name: routeName, startTime: _routeStartTime!, endTime: DateTime.now(), routePoints: List.from(_currentRoutePoints), totalDistance: _currentRouteDistance, totalDuration: _currentRouteDuration, exploredAreas: List.from(_currentRouteExploredAreas));

    await RouteService.saveRoute(route);

    // Başarılı kayıt mesajı
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota kaydedildi: $routeName'), backgroundColor: Colors.green));
    }
  }

  Future<void> _loadPastRoutes() async {
    try {
      final routes = await RouteService.getSavedRoutes();
      setState(() {
        _pastRoutes = routes;
      });
    } catch (e) {
      debugPrint('Geçmiş rotalar yüklenemedi: $e');
    }
  }

  void _togglePastRoutes() {
    setState(() {
      _showPastRoutes = !_showPastRoutes;
    });
    if (_showPastRoutes && _pastRoutes.isEmpty) {
      _loadPastRoutes();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}s ${minutes}d ${seconds}sn';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds}sn';
    } else {
      return '${seconds}sn';
    }
  }

  bool _isNewAreaExplored(LatLng newPosition) {
    for (final exploredArea in _exploredAreas) {
      final distance = Geolocator.distanceBetween(exploredArea.latitude, exploredArea.longitude, newPosition.latitude, newPosition.longitude);
      if (distance < _explorationRadius) {
        return false; // Bu alan zaten keşfedilmiş
      }
    }
    return true; // Yeni alan
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _mapController.camera.zoom);
    }
  }

  Color _getColorForFrequency(int frequency) {
    // Gradient renk paleti: Mavi (az) -> Yeşil -> Sarı -> Turuncu -> Kırmızı (çok)
    final colors = [
      Colors.blue, // 0 kez
      Colors.lightBlue, // 1 kez
      Colors.cyan, // 2 kez
      Colors.teal, // 3 kez
      Colors.green, // 4 kez
      Colors.lightGreen, // 5 kez
      Colors.yellow, // 6 kez
      Colors.orange, // 7 kez
      Colors.deepOrange, // 8 kez
      Colors.red, // 9+ kez
    ];

    // Frekansı array boyutuna göre sınırla
    final clampedFreq = frequency.clamp(0, colors.length - 1);
    return colors[clampedFreq];
  }

  // Coğrafi daire polygon noktaları oluştur
  List<LatLng> _createCirclePoints(LatLng center, double radiusInMeters) {
    const int numPoints = 32; // Daire için nokta sayısı
    final List<LatLng> points = [];

    // Metre cinsinden coğrafi koordinatlara dönüştürme
    // Yaklaşık değerler (enlemde 1 derece = 111320 metre)
    const double metersPerDegreeLat = 111320.0;
    final double metersPerDegreeLng = 111320.0 * cos(center.latitude * pi / 180);

    final double deltaLat = radiusInMeters / metersPerDegreeLat;
    final double deltaLng = radiusInMeters / metersPerDegreeLng;

    for (int i = 0; i < numPoints; i++) {
      final double angle = (i * 2 * pi) / numPoints;
      final double lat = center.latitude + deltaLat * sin(angle);
      final double lng = center.longitude + deltaLng * cos(angle);
      points.add(LatLng(lat, lng));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('World Fog - Keşif Haritası'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _goToCurrentLocation, tooltip: 'Konumuma Git'),
          IconButton(icon: Icon(_showPastRoutes ? Icons.route : Icons.route_outlined), onPressed: _togglePastRoutes, tooltip: _showPastRoutes ? 'Geçmiş Rotaları Gizle' : 'Geçmiş Rotaları Göster'),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
            tooltip: 'Profil ve Rota Geçmişi',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    onThemeChanged: widget.onThemeChanged,
                    onRadiusChanged: (newRadius) {
                      setState(() {
                        _explorationRadius = newRadius;
                      });
                    },
                  ),
                ),
              );
              // Ayarlar sayfasından geri dönüldüğünde ayarları yeniden yükle
              await _loadSettings();
            },
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik paneli
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Keşfedilen Alan', style: TextStyle(fontSize: 12)),
                        Text('${_exploredAreas.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Takip Durumu', style: TextStyle(fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _isTracking ? (_isPaused ? Colors.orange : Colors.green) : Colors.red, borderRadius: BorderRadius.circular(12)),
                          child: Text(_isTracking ? (_isPaused ? 'Duraklatıldı' : 'Aktif') : 'Pasif', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isTracking) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Mesafe', style: TextStyle(fontSize: 12)),
                          Text(
                            _formatDistance(_currentRouteDistance),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Süre', style: TextStyle(fontSize: 12)),
                          Text(
                            _formatDuration(_currentRouteDuration),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Harita
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _currentPosition!, initialZoom: 15.0, minZoom: 5.0, maxZoom: 18.0),
                    children: [
                      TileLayer(
                        urlTemplate: Theme.of(context).brightness == Brightness.dark ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.world_fog',
                        subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                      // Keşfedilen alanlar (Coğrafi alan boyutunu koruyan sis efekti)
                      if (_exploredAreas.isNotEmpty)
                        PolygonLayer(
                          polygons: _exploredAreas.map((area) {
                            // Yakınlık bazlı yoğunluk hesaplama
                            int nearbyCount = 0;
                            for (final otherArea in _exploredAreas) {
                              if (area != otherArea) {
                                final distance = Geolocator.distanceBetween(area.latitude, area.longitude, otherArea.latitude, otherArea.longitude);
                                if (distance < _explorationRadius * 1.5) {
                                  nearbyCount++;
                                }
                              }
                            }

                            // Renk ve opacity hesaplama
                            final color = _getColorForFrequency(nearbyCount);
                            final opacity = (0.15 + (nearbyCount * 0.05)).clamp(0.1, 0.6);

                            // Coğrafi alan için daire polygon oluştur
                            return Polygon(
                              points: _createCirclePoints(area, _explorationRadius),
                              color: color.withValues(alpha: opacity),
                              borderColor: Colors.transparent,
                              borderStrokeWidth: 0,
                            );
                          }).toList(),
                        ),
                      // Geçmiş rotalar
                      if (_showPastRoutes && _pastRoutes.isNotEmpty)
                        PolylineLayer(
                          polylines: _pastRoutes.map((route) {
                            // Her rota için farklı renk
                            final colors = [Colors.purple.withValues(alpha: 0.6), Colors.pink.withValues(alpha: 0.6), Colors.indigo.withValues(alpha: 0.6), Colors.brown.withValues(alpha: 0.6), Colors.grey.withValues(alpha: 0.6)];
                            final colorIndex = _pastRoutes.indexOf(route) % colors.length;

                            return Polyline(points: route.routePoints, color: colors[colorIndex], strokeWidth: 2.0);
                          }).toList(),
                        ),
                      // Mevcut rota çizgisi
                      if (_isTracking && _currentRoutePoints.length > 1)
                        PolylineLayer(
                          polylines: [Polyline(points: _currentRoutePoints, color: _isPaused ? (Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange) : (Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue : Colors.blue), strokeWidth: 4.0)],
                        ),
                      // Mevcut konum
                      if (_currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition!,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isTracking
                                      ? (_isPaused ? (Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange) : (Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue : Colors.blue))
                                      : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          // Geçmiş rotalar bilgi paneli
          if (_showPastRoutes && _pastRoutes.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D2D2D) : Colors.grey[200],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route, size: 16),
                      const SizedBox(width: 8),
                      Text('Geçmiş Rotalar (${_pastRoutes.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pastRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _pastRoutes[index];
                        final colors = [Colors.purple, Colors.pink, Colors.indigo, Colors.brown, Colors.grey];
                        final color = colors[index % colors.length];

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color, width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                route.name.length > 15 ? '${route.name.substring(0, 15)}...' : route.name,
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                              ),
                              Text(route.formattedDistance, style: TextStyle(fontSize: 8, color: color)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: _isTracking
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isPaused) FloatingActionButton(heroTag: "resume", onPressed: _resumeTracking, backgroundColor: Colors.green, child: const Icon(Icons.play_arrow)),
                if (!_isPaused) ...[FloatingActionButton(heroTag: "pause", onPressed: _pauseTracking, backgroundColor: Colors.orange, child: const Icon(Icons.pause)), const SizedBox(height: 16)],
                if (_isPaused) const SizedBox(height: 16),
                FloatingActionButton(heroTag: "stop", onPressed: _stopTracking, backgroundColor: Colors.red, child: const Icon(Icons.stop)),
              ],
            )
          : FloatingActionButton(heroTag: "start", onPressed: _startTracking, backgroundColor: Colors.green, child: const Icon(Icons.play_arrow)),
    );
  }

  // Sürekli konum takibi (rota takibinden bağımsız)
  void _startLocationTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // 10 metre hareket gerekli
          ),
        ).listen((Position position) {
          final newPosition = LatLng(position.latitude, position.longitude);

          // Konum her zaman güncellenir
          setState(() {
            _currentPosition = newPosition;
          });

          // Sadece rota aktifken rota verilerini güncelle
          if (_isTracking && !_isPaused) {
            // Mesafe hesapla
            if (_currentRoutePoints.isNotEmpty) {
              final lastPoint = _currentRoutePoints.last;
              final distance = Geolocator.distanceBetween(lastPoint.latitude, lastPoint.longitude, newPosition.latitude, newPosition.longitude);
              _currentRouteDistance += distance;
            }

            // Yeni noktayı rotaya ekle
            _currentRoutePoints.add(newPosition);

            // Yeni alan keşfedildi mi kontrol et
            if (_isNewAreaExplored(newPosition)) {
              setState(() {
                _exploredAreas.add(newPosition);
                _currentRouteExploredAreas.add(newPosition);
              });
              _saveExploredAreas();
            }
          }
        });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}
