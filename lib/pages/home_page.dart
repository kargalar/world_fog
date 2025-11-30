// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/route_model.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../widgets/main_map_widget.dart';
import '../utils/app_colors.dart';
import '../widgets/route_control_panel.dart';
import '../widgets/route_stats_card.dart';
import '../widgets/world_fog_app.dart';
import '../widgets/route_save_bottomsheet.dart';
import '../widgets/waypoint_dialog.dart';
import '../services/camera_service.dart';
import '../utils/app_strings.dart';

/// Main page widget
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final CameraService _cameraService = CameraService();

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

    // Listen to location updates - Update map UI
    locationVM.addListener(() {
      if (locationVM.hasLocation) {
        final location = locationVM.currentLocation!;

        // Debug: Location update
        debugPrint('📍 Location updated: ${location.position.latitude}, ${location.position.longitude}');

        // Update map UI when location changes
        mapVM.updateMapWithLocation(location);

        // Grid exploration is handled in AppInitializer to work in background too
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
                  return RouteStatsCard(
                    currentRouteDistance: routeVM.currentRouteDistance,
                    currentRouteDuration: routeVM.currentRouteDuration,
                    currentBreakDuration: routeVM.currentBreakDuration,
                    isPaused: routeVM.isPaused,
                    averageSpeed: routeVM.currentAverageSpeed,
                    totalAscent: routeVM.totalAscent,
                    totalDescent: routeVM.totalDescent,
                  );
                },
              ),
            ),
        ],
      ),
      // Fotoğraf ekleme FAB (sadece rota aktifken)
      floatingActionButton: context.watch<RouteViewModel>().isActive
          ? FloatingActionButton(
              onPressed: _addWaypoint,
              backgroundColor: AppColors.deepPurple,
              child: const Icon(Icons.add_a_photo, color: AppColors.white),
            )
          : null,
    );
  }

  /// Add a photo waypoint
  Future<void> _addWaypoint() async {
    final locationVM = context.read<LocationViewModel>();
    final routeVM = context.read<RouteViewModel>();

    if (!locationVM.hasLocation) {
      SnackBarHelper.showError(context, 'Konum bilgisi alınamadı');
      return;
    }

    // Fotoğraf çek
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);

    if (photo == null) return;

    // Waypoint tipini seç
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => WaypointTypeDialog(photoPath: photo.path),
    );

    if (result == null) return;

    // Fotoğrafı kaydet
    final savedPath = await _cameraService.savePhoto(photo.path);

    // Waypoint oluştur ve ekle
    final waypoint = RouteWaypoint(id: DateTime.now().millisecondsSinceEpoch.toString(), position: locationVM.currentPosition!, type: result['type'] as WaypointType, photoPath: savedPath, description: result['description'] as String?, timestamp: DateTime.now());

    routeVM.addWaypoint(waypoint);
    SnackBarHelper.showSuccess(context, 'İşaret eklendi: ${waypoint.typeLabel}');
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
    final averageSpeed = routeVM.currentAverageSpeed;
    final totalAscent = routeVM.totalAscent;
    final totalDescent = routeVM.totalDescent;
    final totalBreakTime = routeVM.totalPausedTime;
    final waypointsCount = routeVM.currentWaypoints.length;

    showRouteSaveBottomSheet(
      context: context,
      distance: distance,
      duration: duration,
      pointsCount: pointsCount,
      averageSpeed: averageSpeed,
      totalAscent: totalAscent,
      totalDescent: totalDescent,
      totalBreakTime: totalBreakTime,
      waypointsCount: waypointsCount,
      onSave: (name, weatherConditions, temperature, rating) async {
        WeatherInfo? weather;
        if (weatherConditions != null && weatherConditions.isNotEmpty) {
          weather = WeatherInfo(condition: weatherConditions.first, conditions: weatherConditions, temperature: temperature);
        }
        await routeVM.stopTrackingWithName(name, weather: weather, rating: rating);
        SnackBarHelper.showSuccess(context, '${AppStrings.routeSavedAs} "$name"');
      },
      onDelete: () {
        routeVM.cancelTracking();
        SnackBarHelper.showSuccess(context, 'Rota silindi');
      },
      onCancel: () {
        // Do nothing, just close the bottom sheet
      },
    );
  }
}
