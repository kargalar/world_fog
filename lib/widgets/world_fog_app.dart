import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../pages/home_page.dart';
import '../utils/app_strings.dart';

/// Main application widget
class WorldFogApp extends StatelessWidget {
  const WorldFogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocationViewModel()),
          ChangeNotifierProvider(create: (_) => MapViewModel()),
          ChangeNotifierProvider(create: (_) => RouteViewModel()),
        ],
        child: const AppInitializer(),
      ),
    );
  }
}

/// Application initializer widget
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final locationVM = context.read<LocationViewModel>();
      final mapVM = context.read<MapViewModel>();
      final routeVM = context.read<RouteViewModel>();

      // Initialize location service
      await locationVM.checkLocationServiceStatus();

      // If location service is available, start location tracking
      if (locationVM.isLocationAvailable) {
        await locationVM.startLocationTracking(distanceFilter: 1);

        // Get initial location
        await locationVM.getCurrentLocation();

        // Center map on current location (when MapController is ready)
        if (locationVM.hasLocation) {
          // MapController may not be ready yet, just update state
          mapVM.updateMapCenter(locationVM.currentPosition!);
        }
      } else {
        // Request location permission
        await locationVM.requestLocationPermission();
      }

      // Load past routes
      await routeVM.loadPastRoutes();

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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: AppStrings.close,
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.blue, duration: const Duration(seconds: 2)));
  }
}
