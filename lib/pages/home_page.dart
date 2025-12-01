// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:location/location.dart';
import '../models/route_model.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../widgets/main_map_widget.dart';
import '../utils/app_colors.dart';
import '../widgets/route_control_panel.dart';
import '../widgets/route_stats_card.dart';
import '../widgets/trodden_app.dart';
import '../widgets/route_save_bottomsheet.dart';
import '../widgets/waypoint_dialog.dart';
import '../services/camera_service.dart';
import '../services/notification_service.dart';
import '../utils/app_strings.dart';

/// Main page widget
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  final CameraService _cameraService = CameraService();
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _locationDisabledWarningShown = false;
  bool _movementWarningDialogShown = false; // Hareket uyarısı dialog'u gösterildi mi

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupLocationListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Uygulama ön plana geldiğinde konum durumunu kontrol et
    if (state == AppLifecycleState.resumed) {
      _checkLocationServiceStatus();
    }
  }

  /// Konum servisi durumunu kontrol et
  Future<void> _checkLocationServiceStatus() async {
    final locationVM = context.read<LocationViewModel>();
    final wasDisabled = !locationVM.serviceStatus.isEnabled;
    await locationVM.checkLocationServiceStatus();

    // Konum servisi yeni açıldıysa stream'i yeniden başlat
    if (wasDisabled && locationVM.serviceStatus.isEnabled) {
      await locationVM.restartLocationService();
      debugPrint('✅ Konum servisi açıldı, stream yeniden başlatıldı');
    }
  }

  /// Listen to location updates
  void _setupLocationListener() {
    final locationVM = context.read<LocationViewModel>();
    final mapVM = context.read<MapViewModel>();
    final routeVM = context.read<RouteViewModel>();

    // Listen to location updates - Update map UI
    locationVM.addListener(() {
      // Konum servisi durumu değiştiğinde kontrol et
      if (locationVM.serviceStatus.isEnabled && _locationDisabledWarningShown) {
        // Konum servisi tekrar açıldı, uyarıyı kaldır ve dialog'u kapat
        _locationDisabledWarningShown = false;
        _notificationService.cancelLocationWarningNotification();
        // Açık dialog varsa kapat
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        // Konum servisini yeniden başlat
        locationVM.restartLocationService();
        debugPrint('✅ Konum servisi açıldı, uyarı kaldırıldı');
      }

      if (locationVM.hasLocation) {
        final location = locationVM.currentLocation!;

        // Debug: Location update
        debugPrint('📍 Location updated: ${location.position.latitude}, ${location.position.longitude}');

        // Update map UI when location changes
        mapVM.updateMapWithLocation(location);

        // Grid exploration is handled in AppInitializer to work in background too
      }

      // Rota aktifken konum servisi kapatıldıysa uyar
      if (routeVM.isTracking && !locationVM.serviceStatus.isEnabled && !_locationDisabledWarningShown) {
        _locationDisabledWarningShown = true;
        _showLocationDisabledWarning();
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
      // Pause halinde hareket algılandığında uyar (sadece 1 kere)
      if (routeVM.movementDetectedWhilePaused && !_movementWarningDialogShown) {
        _showMovementWhilePausedWarning();
      }
      // Pause'dan çıkıldığında veya rota durdurulduğunda flag'i sıfırla
      if (!routeVM.isPaused || !routeVM.isTracking) {
        _movementWarningDialogShown = false;
      }
    });
  }

  /// Konum servisi kapatıldığında büyük uyarı göster
  void _showLocationDisabledWarning() {
    final locationVM = context.read<LocationViewModel>();

    // Bildirim gönder
    _notificationService.showLocationDisabledNotification();

    // Büyük dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        onPopInvokedWithResult: (bool _, _) async {
          // Geri tuşuna basılsa bile dialog kapanmasın
        },
        child: AlertDialog(
          backgroundColor: AppColors.red.withAlpha(230),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Icon(Icons.location_off, color: AppColors.white, size: 64),
              const SizedBox(height: 16),
              const Text(
                'KONUM SERVİSİ KAPALI!',
                style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rota takibi durdu!\n\nDevam etmek için konum servisini açmanız gerekmektedir.',
                style: TextStyle(color: AppColors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                await Location().requestService();
                // Ayarlardan döndükten sonra durumu kontrol et
                await Future.delayed(const Duration(milliseconds: 500));
                await locationVM.checkLocationServiceStatus();
                if (locationVM.serviceStatus.isEnabled) {
                  _locationDisabledWarningShown = false;
                  _notificationService.cancelLocationWarningNotification();
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.location_on),
              label: Text(AppStrings.enableLocation),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.red, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationVM = context.watch<LocationViewModel>();
    final routeVM = context.watch<RouteViewModel>();

    // Rota aktifken konum servisi kontrolü (listener dışında da kontrol)
    if (routeVM.isTracking && !locationVM.serviceStatus.isEnabled && !_locationDisabledWarningShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locationDisabledWarningShown = true;
        _showLocationDisabledWarning();
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Ana harita
          const MainMapWidget(),

          // Harita kontrol butonları
          const MapControlButtons(),

          // Konum kapalı uyarısı overlay (rota aktifken)
          if (routeVM.isTracking && !locationVM.serviceStatus.isEnabled)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    color: AppColors.red,
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off, color: AppColors.white, size: 80),
                          const SizedBox(height: 16),
                          const Text(
                            'KONUM KAPALI',
                            style: TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Rota kaydı durdu.\nKonumu açın.',
                            style: TextStyle(color: AppColors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Location().requestService();
                            },
                            icon: const Icon(Icons.location_on),
                            label: Text(AppStrings.enableLocation),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.red, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Rota kontrol paneli
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Consumer<RouteViewModel>(
              builder: (context, routeVM, child) {
                return RouteControlPanel(
                  isTracking: routeVM.isTracking,
                  isPaused: routeVM.isPaused,
                  currentBreakDuration: routeVM.currentBreakDuration,
                  onStartTracking: () => _startTracking(),
                  onPauseTracking: () => routeVM.pauseTracking(),
                  onResumeTracking: () => routeVM.resumeTracking(),
                  onStopTracking: () => _stopTracking(),
                );
              },
            ),
          ),

          // Rota istatistikleri
          if (routeVM.isTracking)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Consumer<RouteViewModel>(
                builder: (context, routeVM, child) {
                  // Toplam mola süresi = kaydedilen toplam + mevcut mola
                  final totalBreakTime = routeVM.totalPausedTime + routeVM.currentBreakDuration;
                  return RouteStatsCard(
                    currentRouteDistance: routeVM.currentRouteDistance,
                    currentRouteDuration: routeVM.currentRouteDuration,
                    totalBreakDuration: totalBreakTime,
                    isPaused: routeVM.isPaused,
                    averageSpeed: routeVM.currentAverageSpeed,
                    totalAscent: routeVM.totalAscent,
                    totalDescent: routeVM.totalDescent,
                    pointsCount: routeVM.currentRoutePointsCount,
                    waypointsCount: routeVM.currentWaypoints.length,
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

  /// Pause halinde hareket algılandığında uyarı göster
  Future<void> _showMovementWhilePausedWarning() async {
    if (_movementWarningDialogShown) return;
    _movementWarningDialogShown = true;

    final routeVM = context.read<RouteViewModel>();

    // Titreşim çalıştır
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]); // 3 kez titret
    }

    // Uyarı sesi çal (ses dosyası eklendiyse)
    try {
      await _audioPlayer.play(AssetSource('sounds/warning.mp3'));
    } catch (e) {
      // Ses dosyası yoksa sistem sesi çal
      await SystemSound.play(SystemSoundType.alert);
      debugPrint('Uyarı sesi çalınamadı: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.orange),
            const SizedBox(width: 8),
            Text(AppStrings.motionDetected),
          ],
        ),
        content: Text(AppStrings.routePausedWalking),
        actions: [
          TextButton(
            onPressed: () {
              routeVM.clearMovementWarning();
              Navigator.of(dialogContext).pop();
            },
            child: Text(AppStrings.close),
          ),
          ElevatedButton(
            onPressed: () {
              routeVM.resumeTracking();
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: Text(AppStrings.continueLabel),
          ),
        ],
      ),
    );
  }
}
