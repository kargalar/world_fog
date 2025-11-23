import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../pages/home_page.dart';

/// Ana uygulama widget'ı
class WorldFogApp extends StatelessWidget {
  const WorldFogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'World Fog',
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

/// Uygulama başlatıcı widget'ı
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

      // Konum servisini başlat
      await locationVM.checkLocationServiceStatus();

      // Eğer konum servisi kullanılabilirse konum takibini başlat
      if (locationVM.isLocationAvailable) {
        await locationVM.startLocationTracking(distanceFilter: 1);

        // İlk konumu al
        await locationVM.getCurrentLocation();

        // Haritayı mevcut konuma odakla (MapController hazır olduğunda)
        if (locationVM.hasLocation) {
          // MapController henüz hazır olmayabilir, sadece state'i güncelle
          mapVM.updateMapCenter(locationVM.currentPosition!);
        }
      } else {
        // Konum izni iste
        await locationVM.requestLocationPermission();
      }

      // Geçmiş rotaları yükle
      await routeVM.loadPastRoutes();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Uygulama başlatılamadı: $e';
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('World Fog başlatılıyor...')]),
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
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return const HomePage();
  }
}

/// Hata gösterici widget'ı
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
            if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene'))],
          ],
        ),
      ),
    );
  }
}

/// Loading gösterici widget'ı
class LoadingDisplay extends StatelessWidget {
  final String message;

  const LoadingDisplay({super.key, this.message = 'Yükleniyor...'});

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

/// Snackbar yardımcı sınıfı
class SnackBarHelper {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Kapat',
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
