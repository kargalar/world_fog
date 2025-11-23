import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../widgets/main_map_widget.dart';
import '../widgets/route_control_panel.dart';
import '../widgets/route_stats_card.dart';
import '../widgets/world_fog_app.dart';
import '../widgets/route_name_dialog.dart';

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

        // Her konum güncellemesinde grid keşfi yap
        mapVM.exploreNewGrid(location.position);

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

    // Rota detaylarını hazırla
    final distance = routeVM.currentRouteDistance;
    final duration = routeVM.currentRouteDuration;
    final pointsCount = routeVM.currentRoutePointsCount;

    showDialog(
      context: context,
      builder: (context) => RouteNameDialog(
        distance: distance,
        duration: duration,
        pointsCount: pointsCount,
        onSave: (name) async {
          await routeVM.stopTrackingWithName(name);
          SnackBarHelper.showSuccess(context, 'Rota "$name" olarak kaydedildi');
        },
      ),
    );
  }
}
