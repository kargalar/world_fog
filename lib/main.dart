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
import 'widgets/theme_provider.dart';
import 'widgets/route_control_panel.dart';
import 'widgets/route_stats_card.dart';
import 'widgets/exploration_map_widget.dart';
import 'widgets/map_control_buttons.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(child: const WorldFogPage());
  }
}

class WorldFogPage extends StatefulWidget {
  const WorldFogPage({super.key});

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
  final double _distanceFilter = 1.0; // Konum güncellemesi için minimum mesafe (metre)
  double _areaOpacity = 0.3; // Keşfedilen alanların şeffaflığı

  // Rota takibi için yeni değişkenler
  final List<RoutePoint> _currentRoutePoints = [];
  final List<LatLng> _currentRouteExploredAreas = [];
  DateTime? _routeStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPausedTime = Duration.zero;
  Duration _currentBreakDuration = Duration.zero;
  double _currentRouteDistance = 0.0;
  Duration _currentRouteDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _breakTimer;

  // Geçmiş rotaları gösterme için değişkenler
  bool _showPastRoutes = false;
  List<RouteModel> _pastRoutes = [];

  // State değişkenleri
  bool _isFollowingLocation = false;
  LatLng? _lastPosition;
  double? _currentBearing;

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
    final opacity = prefs.getDouble('area_opacity') ?? 0.3;
    setState(() {
      _explorationRadius = radius;
      _areaOpacity = opacity;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('exploration_radius', _explorationRadius);
    await prefs.setDouble('area_opacity', _areaOpacity);
  }

  Future<void> _requestPermissions() async {
    // Önce konum servisinin açık olup olmadığını kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    // Mevcut izin durumunu kontrol et
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog('Konum izni reddedildi. Lütfen ayarlardan konum iznini açın.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDialog('Konum izni kalıcı olarak reddedildi. Lütfen ayarlardan konum iznini açın.');
      return;
    }

    // İzin alındı, konum takibini başlat
    debugPrint('Konum izni alındı: $permission');
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Konum Servisi Kapalı'),
        content: const Text('GPS/Konum servisi kapalı. Lütfen cihazınızın konum servisini açın.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Konum İzni Gerekli'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Önce izinleri ve servisleri kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Konum servisi kapalı');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('Konum izni yok: $permission');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // Timeout ekle
        ),
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_currentPosition!, 15.0);
      debugPrint('Konum alındı: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      // Kullanıcıya hata mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konum alınamadı: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
      }
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
      _currentBreakDuration = Duration.zero;
      _currentRoutePoints.clear();
      _currentRouteExploredAreas.clear();

      // Başlangıç noktasını ekle
      if (_currentPosition != null) {
        _currentRoutePoints.add(
          RoutePoint(
            position: _currentPosition!,
            altitude: 0.0, // İlk nokta için varsayılan yükseklik
            timestamp: DateTime.now(),
          ),
        );
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
    _breakTimer?.cancel();

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
            if (_currentBreakDuration.inSeconds > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.coffee, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 4),
                  Text('Mola Süresi: ${_formatDuration(_currentBreakDuration)}'),
                ],
              ),
            ],
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

      // Mola timer'ını başlat
      _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isPaused) {
          setState(() {
            _currentBreakDuration = _currentBreakDuration + const Duration(seconds: 1);
          });
        }
      });
    });
  }

  void _resumeTracking() {
    // Duraklatma süresini hesapla
    if (_pauseStartTime != null) {
      _totalPausedTime += DateTime.now().difference(_pauseStartTime!);
    }

    // Mola timer'ını durdur
    _breakTimer?.cancel();
    _breakTimer = null;

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

    final route = RouteModel(
      id: routeId,
      name: routeName,
      startTime: _routeStartTime!,
      endTime: DateTime.now(),
      routePoints: List.from(_currentRoutePoints),
      totalDistance: _currentRouteDistance,
      totalDuration: _currentRouteDuration,
      totalBreakTime: _currentBreakDuration,
      exploredAreas: List.from(_currentRouteExploredAreas),
    );

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
      // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! buradaki 100, 100 metrede bir keşfet gibi bir anlama geliyor.
      // TODO:
      if (distance < 100) {
        return false; // Bu alan zaten keşfedilmiş
      }
    }
    return true; // Yeni alan
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null) {
      if (_isFollowingLocation) {
        // Oto takip modundan çıkıyoruz, haritayı sıfırla
        _mapController.moveAndRotate(_currentPosition!, _mapController.camera.zoom, 0);
      } else {
        // Oto takip moduna giriyoruz
        if (_currentBearing != null) {
          _mapController.moveAndRotate(_currentPosition!, _mapController.camera.zoom, -_currentBearing!);
        } else {
          _mapController.move(_currentPosition!, _mapController.camera.zoom);
        }
      }
      setState(() {
        _isFollowingLocation = !_isFollowingLocation;
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  // Sürekli konum takibi (rota takibinden bağımsız)
  void _startLocationTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilter.toInt(), // Kullanıcı tarafından ayarlanabilir
            timeLimit: const Duration(seconds: 30), // Timeout ekle
          ),
        ).listen(
          (Position position) {
            final newPosition = LatLng(position.latitude, position.longitude);

            // Konum her zaman güncellenir
            if (mounted) {
              setState(() {
                _lastPosition = _currentPosition;
                _currentPosition = newPosition;
                if (_lastPosition != null) {
                  _currentBearing = _calculateBearing(_lastPosition!, newPosition);
                }
              });

              if (_isFollowingLocation && _currentPosition != null) {
                // Oto takip modunda haritayı kullanıcının yönüne göre döndür
                if (_currentBearing != null) {
                  _mapController.moveAndRotate(_currentPosition!, _mapController.camera.zoom, -_currentBearing!);
                } else {
                  _mapController.move(_currentPosition!, _mapController.camera.zoom);
                }
              }

              // Sadece rota aktifken rota verilerini güncelle
              if (_isTracking && !_isPaused) {
                // Mesafe hesapla
                if (_currentRoutePoints.isNotEmpty) {
                  final lastPoint = _currentRoutePoints.last;
                  final distance = Geolocator.distanceBetween(lastPoint.position.latitude, lastPoint.position.longitude, newPosition.latitude, newPosition.longitude);
                  _currentRouteDistance += distance;
                }

                // Yeni noktayı rotaya ekle (yükseklik bilgisi ile)
                _currentRoutePoints.add(RoutePoint(position: newPosition, altitude: position.altitude, timestamp: DateTime.now()));

                // Yeni alan keşfedildi mi kontrol et
                if (_isNewAreaExplored(newPosition)) {
                  setState(() {
                    _exploredAreas.add(newPosition);
                    _currentRouteExploredAreas.add(newPosition);
                  });
                  _saveExploredAreas();
                }
              }
            }
          },
          onError: (error) {
            debugPrint('Konum stream hatası: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konum takibi hatası: ${error.toString()}'), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
            }

            // Hata durumunda stream'i yeniden başlat
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                _restartLocationTracking();
              }
            });
          },
          cancelOnError: false, // Hata durumunda stream'i kapatma
        );
  }

  // Konum takibini yeniden başlat
  void _restartLocationTracking() async {
    debugPrint('Konum takibi yeniden başlatılıyor...');

    // Önce mevcut stream'i kapat
    await _positionStream?.cancel();

    // İzinleri ve servisleri kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Konum servisi kapalı - yeniden başlatma iptal edildi');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('Konum izni yok - yeniden başlatma iptal edildi');
      return;
    }

    // Stream'i yeniden başlat
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }

  // Konum durumunu kontrol et ve kullanıcıya bilgi ver
  Future<void> _checkLocationStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    String statusMessage = '';
    Color statusColor = Colors.green;

    if (!serviceEnabled) {
      statusMessage = 'GPS/Konum servisi kapalı';
      statusColor = Colors.red;
    } else if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      statusMessage = 'Konum izni verilmemiş';
      statusColor = Colors.red;
    } else {
      statusMessage = 'Konum takibi aktif';
      statusColor = Colors.green;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(statusMessage), backgroundColor: statusColor, duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: Icon(_isFollowingLocation ? Icons.navigation : Icons.my_location), onPressed: _goToCurrentLocation, tooltip: _isFollowingLocation ? 'Otomatik Takip Kapat' : 'Konumuma Git/Otomatik Takip'),
          IconButton(icon: const Icon(Icons.gps_fixed), onPressed: _checkLocationStatus, tooltip: 'Konum Durumunu Kontrol Et'),
          IconButton(icon: const Icon(Icons.route), onPressed: _togglePastRoutes, tooltip: _showPastRoutes ? 'Geçmiş Rotaları Gizle' : 'Geçmiş Rotaları Göster'),
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
                    onThemeChanged: (themeMode) => ThemeHelper.updateTheme(context, themeMode),
                    onRadiusChanged: (newRadius) async {
                      setState(() {
                        _explorationRadius = newRadius;
                      });
                      await _saveSettings();
                      // Haritadaki duman efektlerini yeniden çiz
                      setState(() {});
                    },

                    onOpacityChanged: (newOpacity) async {
                      setState(() {
                        _areaOpacity = newOpacity;
                      });
                      await _saveSettings();
                      // Haritadaki duman efektlerini yeniden çiz
                      setState(() {});
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
                      if (_currentBreakDuration.inSeconds > 0)
                        Column(
                          children: [
                            const Text('Mola', style: TextStyle(fontSize: 12)),
                            Text(
                              _formatDuration(_currentBreakDuration),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
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
                      // Keşfedilen alanlar (Duman efekti)
                      if (_exploredAreas.isNotEmpty)
                        PolygonLayer(
                          polygons: _exploredAreas.expand((area) {
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

                            // Renk ve opacity hesaplama - opacity sabit kalır, sadece renk değişir
                            final color = _getColorForFrequency(nearbyCount);
                            final baseOpacity = _areaOpacity; // Kullanıcı ayarından sabit opacity - her katman için aynı kalacak

                            // Duman bulutları için seed oluştur (tutarlı şekil için)
                            final seed = area.latitude.hashCode ^ area.longitude.hashCode;

                            // Çoklu katmanlı duman efekti oluştur - opacity sabit kalır, sadece renk değişir
                            return _createMultiLayerSmokeWithFixedOpacity(area, _explorationRadius, color, baseOpacity, seed);
                          }).toList(),
                        ),
                      // Geçmiş rotalar
                      if (_showPastRoutes && _pastRoutes.isNotEmpty)
                        PolylineLayer(
                          polylines: _pastRoutes.map((route) {
                            // Her rota için farklı renk - mavi ile kırmızı arası gradient
                            final colors = [Colors.blue.withValues(alpha: 0.8), Colors.indigo.withValues(alpha: 0.8), Colors.purple.withValues(alpha: 0.8), Colors.pink.withValues(alpha: 0.8), Colors.red.withValues(alpha: 0.8)];
                            final colorIndex = _pastRoutes.indexOf(route) % colors.length;

                            return Polyline(points: route.routePoints.map((p) => p.position).toList(), color: colors[colorIndex], strokeWidth: 2.0);
                          }).toList(),
                        ),
                      // Mevcut rota çizgisi
                      if (_isTracking && _currentRoutePoints.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _currentRoutePoints.map((p) => p.position).toList(),
                              color: _isPaused ? (Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange) : (Theme.of(context).brightness == Brightness.dark ? Colors.lightBlue : Colors.blue),
                              strokeWidth: 4.0,
                            ),
                          ],
                        ),
                      // Mevcut konum
                      if (_currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition!,
                              width: 40,
                              height: 40,
                              child: Icon(Icons.navigation, color: Colors.blue, size: 40), // Ok her zaman yukarı bakar
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

  Color _getColorForFrequency(int visitCount) {
    // Visit count'a göre gradient renk paleti: Açık mavi (1 kez) -> Kırmızı (çok)
    final colors = [
      Colors.lightBlue.shade100, // 1 kez - çok açık mavi
      Colors.lightBlue.shade200, // 2 kez
      Colors.lightBlue.shade300, // 3 kez
      Colors.blue.shade300, // 4 kez
      Colors.blue.shade400, // 5 kez
      Colors.purple.shade300, // 6 kez - mor geçiş
      Colors.purple.shade400, // 7 kez
      Colors.pink.shade300, // 8 kez - pembe
      Colors.red.shade400, // 9 kez - kırmızı
      Colors.red.shade600, // 10 kez - koyu kırmızı
      Colors.red.shade800, // 11+ kez - çok koyu kırmızı
    ];

    // Visit count'u 1-based yapalım (minimum 1 olacak şekilde)
    final adjustedCount = (visitCount - 1).clamp(0, colors.length - 1);
    return colors[adjustedCount];
  }

  // Duman efekti için yumuşak şekil polygon noktaları oluştur
  List<LatLng> _createSmokeCloudPoints(LatLng center, double radiusInMeters, int seed) {
    const int numPoints = 24; // Daha az nokta ile yumuşak şekil
    final List<LatLng> points = [];
    final Random random = Random(seed); // Tutarlı şekil için seed kullan

    // Coğrafi koordinat sisteminde metre cinsinden offset hesaplama
    const double metersPerDegree = 111320;

    for (int i = 0; i < numPoints; i++) {
      final angle = (i * 360 / numPoints) * (pi / 180);

      // Radius'a rastgele varyasyon ekle (daha organik görünüm için)
      final radiusVariation = 0.7 + (random.nextDouble() * 0.6); // 0.7x - 1.3x arasında
      final adjustedRadius = radiusInMeters * radiusVariation;

      // Koordinat offsetleri hesapla
      final dx = adjustedRadius * cos(angle) / metersPerDegree;
      final dy = adjustedRadius * sin(angle) / (metersPerDegree * cos(center.latitude * pi / 180));

      points.add(LatLng(center.latitude + dy, center.longitude + dx));
    }

    return points;
  }

  // Çoklu katmanlı duman efekti oluştur - opacity sabit kalır, sadece renk değişir
  List<Polygon> _createMultiLayerSmokeWithFixedOpacity(LatLng center, double radius, Color color, double opacity, int seed) {
    final polygons = <Polygon>[];

    // 3 katmanlı duman efekti
    for (int layer = 0; layer < 3; layer++) {
      final layerRadius = radius * (0.6 + (layer * 0.2)); // %60, %80, %100 boyutlarında katmanlar
      final layerSeed = seed + (layer * 1000);

      // Her katman için aynı opacity kullan - sadece renk değişir
      Color layerColor = color;
      if (layer == 1) {
        // İkinci katman için rengi biraz daha açık yap
        layerColor = Color.lerp(color, Colors.white, 0.1) ?? color;
      } else if (layer == 2) {
        // Üçüncü katman için rengi biraz daha açık yap
        layerColor = Color.lerp(color, Colors.white, 0.2) ?? color;
      }

      final points = _createSmokeCloudPoints(center, layerRadius, layerSeed);

      polygons.add(
        Polygon(
          points: points,
          color: layerColor.withValues(alpha: opacity), // Sabit opacity
          borderColor: layerColor.withValues(alpha: opacity * 0.7), // Border da sabit opacity
          borderStrokeWidth: 0.5,
        ),
      );
    }

    return polygons;
  }
}
