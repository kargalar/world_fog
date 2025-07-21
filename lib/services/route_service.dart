import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/route_model.dart';

class RouteService {
  static const String _routesKey = 'saved_routes';

  static Future<List<RouteModel>> getSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesString = prefs.getString(_routesKey);

    if (routesString == null) {
      return [];
    }

    try {
      final routesJson = jsonDecode(routesString) as List<dynamic>;
      return routesJson.map((routeJson) => RouteModel.fromJson(routeJson as Map<String, dynamic>)).toList();
    } catch (e) {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  static Future<void> saveRoute(RouteModel route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();

    // Aynı ID'ye sahip rota varsa güncelle
    final existingIndex = routes.indexWhere((r) => r.id == route.id);
    if (existingIndex != -1) {
      routes[existingIndex] = route;
    } else {
      routes.add(route);
    }

    final routesJson = routes.map((route) => route.toJson()).toList();
    final routesString = jsonEncode(routesJson);
    await prefs.setString(_routesKey, routesString);
  }

  static Future<void> deleteRoute(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();

    routes.removeWhere((route) => route.id == routeId);

    final routesJson = routes.map((route) => route.toJson()).toList();
    final routesString = jsonEncode(routesJson);
    await prefs.setString(_routesKey, routesString);
  }

  static Future<RouteModel?> getRoute(String routeId) async {
    final routes = await getSavedRoutes();
    try {
      return routes.firstWhere((route) => route.id == routeId);
    } catch (e) {
      return null;
    }
  }
}
