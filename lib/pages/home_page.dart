import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../models/location_model.dart';
import '../widgets/main_map_widget.dart';
import '../widgets/route_control_panel.dart';
import '../widgets/route_stats_card.dart';
import '../widgets/world_fog_app.dart';
import 'profile_page.dart';
import 'settings_page.dart';

/// Ana sayfa widget'ı
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _setupLocationListener();
  }

  /// Konum güncellemelerini dinle
  void _setupLocationListener() {
    final locationVM = context.read<LocationViewModel>();
    final mapVM = context.read<MapViewModel>();
    final routeVM = context.read<RouteViewModel>();

    // Konum güncellemelerini dinle
    locationVM.addListener(() {
      if (locationVM.hasLocation) {
        final location = locationVM.currentLocation!;

        // Debug: Konum güncellemesi
        debugPrint('📍 Konum güncellendi: ${location.position.latitude}, ${location.position.longitude}');

        // Haritayı güncelle
        mapVM.updateMapWithLocation(location);

        // Her konum güncellemesinde alan keşfi yap (sıcaklık haritası için)
        mapVM.exploreNewArea(location.position);

        // Aktif rota varsa konum noktası ekle
        if (routeVM.isActive) {
          routeVM.addLocationPoint(location);
        }
      }
    });

    // Hata mesajlarını göster
    locationVM.addListener(() {
      if (locationVM.errorMessage != null) {
        SnackBarHelper.showError(context, locationVM.errorMessage!);
        locationVM.clearError();
      }
    });

    mapVM.addListener(() {
      if (mapVM.errorMessage != null) {
        SnackBarHelper.showError(context, mapVM.errorMessage!);
        mapVM.clearError();
      }
    });

    routeVM.addListener(() {
      if (routeVM.errorMessage != null) {
        SnackBarHelper.showError(context, routeVM.errorMessage!);
        routeVM.clearError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Ana harita
          const MainMapWidget(),

          // Harita kontrol butonları
          const MapControlButtons(),

          // Rota kontrol paneli
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Consumer<RouteViewModel>(
              builder: (context, routeVM, child) {
                return RouteControlPanel(isTracking: routeVM.isTracking, isPaused: routeVM.isPaused, onStartTracking: () => _startTracking(), onPauseTracking: () => routeVM.pauseTracking(), onResumeTracking: () => routeVM.resumeTracking(), onStopTracking: () => _stopTracking());
              },
            ),
          ),

          // Rota istatistikleri
          if (context.watch<RouteViewModel>().isTracking)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Consumer<RouteViewModel>(
                builder: (context, routeVM, child) {
                  return RouteStatsCard(currentRouteDistance: routeVM.currentRouteDistance, currentRouteDuration: routeVM.currentRouteDuration, currentBreakDuration: routeVM.currentBreakDuration, isPaused: routeVM.isPaused);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// AppBar oluştur
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: const Text('World Fog'),
      actions: [
        // Konum durumu butonu
        Consumer<LocationViewModel>(
          builder: (context, locationVM, child) {
            return IconButton(
              icon: Icon(locationVM.isLocationAvailable ? Icons.gps_fixed : Icons.gps_off, color: locationVM.isLocationAvailable ? Colors.green : Colors.red),
              onPressed: () => _showLocationStatusDialog(),
              tooltip: 'Konum Durumu',
            );
          },
        ),

        // Geçmiş rotalar butonu
        Consumer<MapViewModel>(
          builder: (context, mapVM, child) {
            return IconButton(
              icon: Icon(mapVM.showPastRoutes ? Icons.visibility_off : Icons.visibility, color: mapVM.showPastRoutes ? Colors.orange : null),
              onPressed: () => mapVM.togglePastRoutes(),
              tooltip: mapVM.showPastRoutes ? 'Geçmiş Rotaları Gizle' : 'Geçmiş Rotaları Göster',
            );
          },
        ),

        // Profil butonu
        IconButton(icon: const Icon(Icons.person), onPressed: () => _navigateToProfile(), tooltip: 'Profil ve Rota Geçmişi'),

        // Ayarlar butonu
        IconButton(icon: const Icon(Icons.settings), onPressed: () => _navigateToSettings(), tooltip: 'Ayarlar'),
      ],
    );
  }

  /// Rota takibini başlat
  void _startTracking() {
    final locationVM = context.read<LocationViewModel>();
    final routeVM = context.read<RouteViewModel>();

    if (!locationVM.isLocationAvailable) {
      SnackBarHelper.showError(context, 'Konum servisi kullanılamıyor');
      return;
    }

    routeVM.startTracking(locationVM.currentPosition);
    SnackBarHelper.showSuccess(context, 'Rota takibi başlatıldı');
  }

  /// Rota takibini durdur
  void _stopTracking() {
    final routeVM = context.read<RouteViewModel>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rota Takibini Durdur'),
        content: const Text('Rota takibini durdurmak istediğinizden emin misiniz? Rota kaydedilecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              routeVM.stopTracking();
              SnackBarHelper.showSuccess(context, 'Rota kaydedildi');
            },
            child: const Text('Durdur'),
          ),
        ],
      ),
    );
  }

  /// Konum durumu dialog'unu göster
  void _showLocationStatusDialog() {
    final locationVM = context.read<LocationViewModel>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konum Durumu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Konum Servisi', locationVM.serviceStatus.isEnabled),
            _buildStatusRow('Konum İzni', locationVM.serviceStatus.permissionStatus == LocationPermissionStatus.granted),
            _buildStatusRow('Konum Takibi', locationVM.isTracking),
            if (locationVM.hasLocation) ...[
              const SizedBox(height: 8),
              Text('Enlem: ${locationVM.currentPosition!.latitude.toStringAsFixed(6)}'),
              Text('Boylam: ${locationVM.currentPosition!.longitude.toStringAsFixed(6)}'),
              if (locationVM.currentBearing != null) Text('Yön: ${locationVM.currentBearing!.toStringAsFixed(1)}°'),
            ],
          ],
        ),
        actions: [
          if (!locationVM.isLocationAvailable) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                locationVM.openLocationSettings();
              },
              child: const Text('Konum Ayarları'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                locationVM.openAppSettings();
              },
              child: const Text('Uygulama Ayarları'),
            ),
          ],
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );
  }

  /// Durum satırı oluştur
  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(status ? Icons.check_circle : Icons.cancel, color: status ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  /// Profil sayfasına git
  void _navigateToProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
  }

  /// Ayarlar sayfasına git
  void _navigateToSettings() async {
    final mapVM = context.read<MapViewModel>();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onThemeChanged: (themeMode) {
            // Tema değişikliği artık MaterialApp seviyesinde yapılmıyor
            // İleride gerekirse burada tema state'i güncellenebilir
          },
          onRadiusChanged: (newRadius) => mapVM.updateExplorationRadius(newRadius),
          onOpacityChanged: (newOpacity) => mapVM.updateAreaOpacity(newOpacity),
        ),
      ),
    );
  }
}
