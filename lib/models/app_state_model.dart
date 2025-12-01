import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Uygulama ayarlarını tutan model
class AppSettingsModel {
  final double explorationRadius;
  final double areaOpacity;
  final double distanceFilter;
  final bool isSatelliteView;
  final bool showPastRoutes;

  const AppSettingsModel({this.explorationRadius = 100.0, this.areaOpacity = 0.7, this.distanceFilter = 10.0, this.isSatelliteView = false, this.showPastRoutes = false});

  AppSettingsModel copyWith({double? explorationRadius, double? areaOpacity, double? distanceFilter, bool? isSatelliteView, bool? showPastRoutes}) {
    return AppSettingsModel(
      explorationRadius: explorationRadius ?? this.explorationRadius,
      areaOpacity: areaOpacity ?? this.areaOpacity,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      isSatelliteView: isSatelliteView ?? this.isSatelliteView,
      showPastRoutes: showPastRoutes ?? this.showPastRoutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {'explorationRadius': explorationRadius, 'areaOpacity': areaOpacity, 'distanceFilter': distanceFilter, 'isSatelliteView': isSatelliteView, 'showPastRoutes': showPastRoutes};
  }

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      explorationRadius: json['explorationRadius']?.toDouble() ?? 50.0,
      areaOpacity: json['areaOpacity']?.toDouble() ?? 0.3,
      distanceFilter: json['distanceFilter']?.toDouble() ?? 10.0,
      isSatelliteView: json['isSatelliteView'] ?? false,
      showPastRoutes: json['showPastRoutes'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsModel && other.explorationRadius == explorationRadius && other.areaOpacity == areaOpacity && other.distanceFilter == distanceFilter && other.isSatelliteView == isSatelliteView && other.showPastRoutes == showPastRoutes;
  }

  @override
  int get hashCode {
    return explorationRadius.hashCode ^ areaOpacity.hashCode ^ distanceFilter.hashCode ^ isSatelliteView.hashCode ^ showPastRoutes.hashCode;
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
  final Set<String> exploredGrids;
  final DateTime lastUpdated;

  const ExploredAreaModel({required this.exploredGrids, required this.lastUpdated});

  ExploredAreaModel copyWith({Set<String>? exploredGrids, DateTime? lastUpdated}) {
    return ExploredAreaModel(exploredGrids: exploredGrids ?? this.exploredGrids, lastUpdated: lastUpdated ?? this.lastUpdated);
  }

  ExploredAreaModel addGrid(String gridKey) {
    return ExploredAreaModel(exploredGrids: {...exploredGrids, gridKey}, lastUpdated: DateTime.now());
  }

  bool isGridExplored(String gridKey) {
    return exploredGrids.contains(gridKey);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExploredAreaModel && other.exploredGrids.length == exploredGrids.length && other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return exploredGrids.hashCode ^ lastUpdated.hashCode;
  }
}
