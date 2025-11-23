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
import '../utils/app_strings.dart';

/// Main page widget
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

  /// Listen to location updates
  void _setupLocationListener() {
    final locationVM = context.read<LocationViewModel>();
    final mapVM = context.read<MapViewModel>();
    final routeVM = context.read<RouteViewModel>();

    // Listen to location updates
    locationVM.addListener(() {
      if (locationVM.hasLocation) {
        final location = locationVM.currentLocation!;

        // Debug: Location update
        debugPrint('📍 Location updated: ${location.position.latitude}, ${location.position.longitude}');

        // Update map
        mapVM.updateMapWithLocation(location);

        // Explore new grid on every location update
        mapVM.exploreNewGrid(location.position);

        // Add location point if active route
        if (routeVM.isActive) {
          routeVM.addLocationPoint(location);
        }
      }
    });

    // Show error messages
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

  /// Start route tracking
  void _startTracking() {
    final locationVM = context.read<LocationViewModel>();
    final routeVM = context.read<RouteViewModel>();

    if (!locationVM.isLocationAvailable) {
      SnackBarHelper.showError(context, AppStrings.locationServiceUnavailable);
      return;
    }

    routeVM.startTracking(locationVM.currentPosition);
    SnackBarHelper.showSuccess(context, AppStrings.routeTrackingStarted);
  }

  /// Stop route tracking
  void _stopTracking() {
    final routeVM = context.read<RouteViewModel>();

    // Prepare route details
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
          SnackBarHelper.showSuccess(context, '${AppStrings.routeSavedAs} "$name"');
        },
      ),
    );
  }
}
