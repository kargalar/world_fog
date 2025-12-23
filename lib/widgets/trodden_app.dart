import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/location_model.dart';
import '../pages/home_page.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../utils/app_colors.dart';

/// Main application widget
class TroddenApp extends StatelessWidget {
  const TroddenApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider'ı MaterialApp'ın dışına taşıyarak tüm route'larda erişilebilir olmasını sağla
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationViewModel()),
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => RouteViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ],
      child: MaterialApp(title: AppStrings.appName, debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, themeMode: ThemeMode.light, home: const AppInitializer()),
    );
  }
}

/// Application initializer widget
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with WidgetsBindingObserver {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final routeVM = context.read<RouteViewModel>();

    if (state == AppLifecycleState.resumed) {
      // App came to foreground - process any buffered location points
      debugPrint('📱 App resumed - processing buffered locations');
      routeVM.processBufferedLocations();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - enable buffering and save state
      debugPrint('📱 App paused - enabling location buffering and saving state');
      routeVM.enableLocationBuffering();
      routeVM.saveActiveRouteState();
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated - save state
      debugPrint('📱 App detached - saving active route state');
      routeVM.saveActiveRouteState();
    }
  }

  Future<void> _initializeApp() async {
    try {
      final locationVM = context.read<LocationViewModel>();
      final mapVM = context.read<MapViewModel>();
      final routeVM = context.read<RouteViewModel>();

      // Initialize location service
      await locationVM.checkLocationServiceStatus();

      // Konum servisi kapalıysa veya izin yoksa açma isteği gönder
      if (!locationVM.isLocationAvailable) {
        // Konum servisi kapalıysa kullanıcıya sor
        if (!locationVM.serviceStatus.isEnabled) {
          await _showLocationServiceDisabledDialog(locationVM);
        } else if (locationVM.serviceStatus.permissionStatus != LocationPermissionStatus.granted) {
          // İzin yoksa izin iste
          await locationVM.requestLocationPermission();

          // Hala izin verilmediyse dialog göster
          if (!locationVM.isLocationAvailable) {
            await _showLocationPermissionDialog(locationVM);
          }
        }
      }

      // If location service is available, start location tracking
      if (locationVM.isLocationAvailable) {
        await locationVM.startLocationTracking(); // Uses default distanceFilter: 0 for real-time tracking

        // Get initial location
        await locationVM.getCurrentLocation();

        // Center map on current location (when MapController is ready)
        if (locationVM.hasLocation) {
          // MapController may not be ready yet, just update state
          mapVM.updateMapCenter(locationVM.currentPosition!);
          // Son bilinen konumu kaydet
          await mapVM.saveLastKnownLocation(locationVM.currentPosition!);
        }
      }

      // Load past routes
      await routeVM.loadPastRoutes();

      // Aktif rota state'ini geri yükle (uygulama kapatılmışsa)
      final hasActiveRoute = await routeVM.restoreActiveRouteState();
      if (hasActiveRoute) {
        debugPrint('📍 Aktif rota geri yüklendi');
      }

      // Rota gridleri keşfetme callback'i ayarla
      // Bu sayede, rota noktaları eklenirken aradaki tüm gridler keşfedilir
      routeVM.setGridExplorationCallback(mapVM.exploreRouteGrids);

      // Setup background location listener for grid exploration
      // Bu, uygulamanın arkaplanda olması durumunda da gridleri keşfetmesini sağlar
      _setupBackgroundLocationListener(locationVM, mapVM, routeVM);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${AppStrings.appStartFailed}$e';
        _isInitialized = true;
      });
    }
  }

  /// Arkaplanda konum güncellemelerini dinleyerek grid'leri keşfet
  void _setupBackgroundLocationListener(LocationViewModel locationVM, MapViewModel mapVM, RouteViewModel routeVM) {
    // LocationViewModel'in location listener'ını kullan
    // Bu, uygulamanın UI'de olup olmadığına bakılmaksızın devam eder
    locationVM.addListener(() {
      if (locationVM.hasLocation) {
        final location = locationVM.currentLocation!;

        // Konum her güncellendiğinde grid'i keşfet
        mapVM.exploreNewGrid(location.position);

        // Son bilinen konumu kaydet (her konum güncellemesinde değil, belirli aralıklarla)
        mapVM.saveLastKnownLocation(location.position);

        // Rota takip ediliyorsa (pause dahil) konum noktası ekle
        if (routeVM.isTracking) {
          routeVM.addLocationPoint(location);
        }
      }
    });
  }

  /// Konum servisi kapalı dialog'u
  Future<void> _showLocationServiceDisabledDialog(LocationViewModel locationVM) async {
    // Önce izin iste, sonra servisi aç
    await Location().requestPermission();
    await Location().requestService();
    // Kullanıcı dialog'dan döndükten sonra tekrar kontrol et
    await Future.delayed(const Duration(milliseconds: 500));
    await locationVM.checkLocationServiceStatus();
  }

  /// Konum izni dialog'u
  Future<void> _showLocationPermissionDialog(LocationViewModel locationVM) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_disabled, color: AppColors.orange),
            const SizedBox(width: 8),
            Text(AppStrings.locationPermissionRequired),
          ],
        ),
        content: Text(AppStrings.locationPermissionMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppStrings.later)),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: Text(AppStrings.grantPermission),
          ),
        ],
      ),
    );

    if (result == true) {
      // Kalıcı olarak reddedilmişse uygulama ayarlarına yönlendir
      if (locationVM.serviceStatus.permissionStatus == LocationPermissionStatus.deniedForever) {
        await locationVM.openAppSettings();
      } else {
        await locationVM.requestLocationPermission();
      }
      await Future.delayed(const Duration(seconds: 1));
      await locationVM.checkLocationServiceStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text(AppStrings.startingApp)]),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isInitialized = false;
                    _errorMessage = null;
                  });
                  _initializeApp();
                },
                child: const Text(AppStrings.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    return const HomePage();
  }
}

/// Error display widget
class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorDisplay({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text(AppStrings.tryAgain))],
          ],
        ),
      ),
    );
  }
}

/// Loading display widget
class LoadingDisplay extends StatelessWidget {
  final String message;

  const LoadingDisplay({super.key, this.message = AppStrings.loading});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Snackbar helper class
class SnackBarHelper {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: AppStrings.close,
          textColor: AppColors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.green, duration: const Duration(seconds: 2)));
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.blue, duration: const Duration(seconds: 2)));
  }
}
