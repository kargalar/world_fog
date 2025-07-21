import 'package:latlong2/latlong.dart';

/// Uygulama ayarlarını tutan model
class AppSettingsModel {
  final double explorationRadius;
  final double areaOpacity;
  final double distanceFilter;

  const AppSettingsModel({this.explorationRadius = 50.0, this.areaOpacity = 0.3, this.distanceFilter = 10.0});

  AppSettingsModel copyWith({double? explorationRadius, double? areaOpacity, double? distanceFilter}) {
    return AppSettingsModel(explorationRadius: explorationRadius ?? this.explorationRadius, areaOpacity: areaOpacity ?? this.areaOpacity, distanceFilter: distanceFilter ?? this.distanceFilter);
  }

  Map<String, dynamic> toJson() {
    return {'explorationRadius': explorationRadius, 'areaOpacity': areaOpacity, 'distanceFilter': distanceFilter};
  }

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(explorationRadius: json['explorationRadius']?.toDouble() ?? 50.0, areaOpacity: json['areaOpacity']?.toDouble() ?? 0.3, distanceFilter: json['distanceFilter']?.toDouble() ?? 10.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsModel && other.explorationRadius == explorationRadius && other.areaOpacity == areaOpacity && other.distanceFilter == distanceFilter;
  }

  @override
  int get hashCode {
    return explorationRadius.hashCode ^ areaOpacity.hashCode ^ distanceFilter.hashCode;
  }
}

/// Harita durumunu tutan model
class MapStateModel {
  final LatLng? center;
  final double zoom;
  final double rotation;
  final bool isFollowingLocation;
  final bool showPastRoutes;

  const MapStateModel({this.center, this.zoom = 15.0, this.rotation = 0.0, this.isFollowingLocation = false, this.showPastRoutes = false});

  MapStateModel copyWith({LatLng? center, double? zoom, double? rotation, bool? isFollowingLocation, bool? showPastRoutes}) {
    return MapStateModel(center: center ?? this.center, zoom: zoom ?? this.zoom, rotation: rotation ?? this.rotation, isFollowingLocation: isFollowingLocation ?? this.isFollowingLocation, showPastRoutes: showPastRoutes ?? this.showPastRoutes);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStateModel && other.center == center && other.zoom == zoom && other.rotation == rotation && other.isFollowingLocation == isFollowingLocation && other.showPastRoutes == showPastRoutes;
  }

  @override
  int get hashCode {
    return center.hashCode ^ zoom.hashCode ^ rotation.hashCode ^ isFollowingLocation.hashCode ^ showPastRoutes.hashCode;
  }
}

/// Keşfedilen alanları tutan model
class ExploredAreaModel {
  final List<LatLng> areas;
  final DateTime lastUpdated;

  const ExploredAreaModel({required this.areas, required this.lastUpdated});

  ExploredAreaModel copyWith({List<LatLng>? areas, DateTime? lastUpdated}) {
    return ExploredAreaModel(areas: areas ?? this.areas, lastUpdated: lastUpdated ?? this.lastUpdated);
  }

  ExploredAreaModel addArea(LatLng newArea) {
    return ExploredAreaModel(areas: [...areas, newArea], lastUpdated: DateTime.now());
  }

  ExploredAreaModel addAreas(List<LatLng> newAreas) {
    return ExploredAreaModel(areas: [...areas, ...newAreas], lastUpdated: DateTime.now());
  }

  bool isAreaExplored(LatLng position, double radius) {
    for (final area in areas) {
      final distance = _calculateDistance(area, position);
      if (distance < radius) {
        return true;
      }
    }
    return false;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Geolocator kullanarak mesafe hesapla - daha doğru sonuç verir
    return _distanceBetween(point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  // Basit mesafe hesaplama fonksiyonu
  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    final double a = (dLat / 2) * (dLat / 2) + (lat1 * 3.14159265359 / 180) * (lat2 * 3.14159265359 / 180) * (dLon / 2) * (dLon / 2);
    final double c = 2 * (a < 1 ? a : 1);
    return earthRadius * c;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExploredAreaModel && other.areas.length == areas.length && other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return areas.hashCode ^ lastUpdated.hashCode;
  }
}
