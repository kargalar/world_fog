import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana tema sağlayıcı widget'ı
/// Uygulamanın tema durumunu yönetir ve çocuk widget'lara MaterialApp sağlar
class ThemeProvider extends StatefulWidget {
  final Widget child;

  const ThemeProvider({super.key, required this.child});

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();

  /// Context'ten ThemeProvider'a erişim sağlar
  static _ThemeProviderState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ThemeProviderState>();
  }
}

class _ThemeProviderState extends State<ThemeProvider> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  /// SharedPreferences'tan tema ayarını yükler
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('theme_mode') ?? 0;
      if (mounted) {
        setState(() {
          _themeMode = ThemeMode.values[themeIndex];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _themeMode = ThemeMode.system;
          _isLoading = false;
        });
      }
    }
  }

  /// Tema durumunu günceller ve SharedPreferences'a kaydeder
  Future<void> updateTheme(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', themeMode.index);
    } catch (e) {
      debugPrint('Tema ayarı kaydedilirken hata oluştu: $e');
    }
  }

  /// Mevcut tema modunu döndürür
  ThemeMode get currentTheme => _themeMode;

  /// Tema yüklenme durumunu döndürür
  bool get isLoading => _isLoading;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(title: 'World Fog - Keşif Haritası', theme: _buildLightTheme(), darkTheme: _buildDarkTheme(), themeMode: _themeMode, home: widget.child, debugShowCheckedModeBanner: false);
  }

  /// Açık tema yapılandırması
  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    );
  }

  /// Koyu tema yapılandırması
  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F), foregroundColor: Colors.white, centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    );
  }
}

/// Tema yardımcı sınıfı
/// Statik metodlarla tema işlemlerini kolaylaştırır
class ThemeHelper {
  /// Context'ten tema sağlayıcısına erişir ve tema günceller
  static Future<void> updateTheme(BuildContext context, ThemeMode themeMode) async {
    final themeProvider = ThemeProvider.of(context);
    if (themeProvider != null) {
      await themeProvider.updateTheme(themeMode);
    }
  }

  /// Mevcut tema modunu döndürür
  static ThemeMode? getCurrentTheme(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    return themeProvider?.currentTheme;
  }

  /// Tema yüklenme durumunu döndürür
  static bool isThemeLoading(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    return themeProvider?.isLoading ?? false;
  }

  /// Mevcut tema açık tema mı kontrol eder
  static bool isLightTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light;
  }

  /// Mevcut tema koyu tema mı kontrol eder
  static bool isDarkTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark;
  }
}
