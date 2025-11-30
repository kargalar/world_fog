import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePoint {
  final LatLng position;
  final double altitude; // altitude in meters
  final DateTime timestamp;

  RoutePoint({required this.position, required this.altitude, required this.timestamp});

  Map<String, dynamic> toJson() {
    return {'latitude': position.latitude, 'longitude': position.longitude, 'altitude': altitude, 'timestamp': timestamp.toIso8601String()};
  }

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(position: LatLng(json['latitude'], json['longitude']), altitude: json['altitude']?.toDouble() ?? 0.0, timestamp: DateTime.parse(json['timestamp']));
  }
}

/// Rota üzerindeki fotoğraf işaretleri için model
enum WaypointType {
  scenery, // Scenery
  fountain, // Fountain
  junction, // Junction
  waterfall, // Waterfall
  breakPoint, // Break
  other, // Other
}

class RouteWaypoint {
  final String id;
  final LatLng position;
  final WaypointType type;
  final String? photoPath;
  final String? description;
  final DateTime timestamp;

  RouteWaypoint({required this.id, required this.position, required this.type, this.photoPath, this.description, required this.timestamp});

  Map<String, dynamic> toJson() {
    return {'id': id, 'latitude': position.latitude, 'longitude': position.longitude, 'type': type.index, 'photoPath': photoPath, 'description': description, 'timestamp': timestamp.toIso8601String()};
  }

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(id: json['id'], position: LatLng(json['latitude'], json['longitude']), type: WaypointType.values[json['type'] ?? 0], photoPath: json['photoPath'], description: json['description'], timestamp: DateTime.parse(json['timestamp']));
  }

  String get typeLabel {
    switch (type) {
      case WaypointType.scenery:
        return 'Scenery';
      case WaypointType.fountain:
        return 'Fountain';
      case WaypointType.junction:
        return 'Junction';
      case WaypointType.waterfall:
        return 'Waterfall';
      case WaypointType.breakPoint:
        return 'Break';
      case WaypointType.other:
        return 'Other';
    }
  }
}

/// Hava durumu bilgisi için model
enum WeatherCondition {
  sunny, // Sunny
  cloudy, // Cloudy
  rainy, // Rainy
  snowy, // Snowy
  windy, // Windy
  foggy, // Foggy
}

class WeatherInfo {
  final WeatherCondition condition;
  final List<WeatherCondition> conditions; // Multiple weather conditions support
  final double? temperature; // Celsius
  final String? notes;

  WeatherInfo({required this.condition, List<WeatherCondition>? conditions, this.temperature, this.notes}) : conditions = conditions ?? [condition];

  Map<String, dynamic> toJson() {
    return {'condition': condition.index, 'conditions': conditions.map((c) => c.index).toList(), 'temperature': temperature, 'notes': notes};
  }

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final primaryCondition = WeatherCondition.values[json['condition'] ?? 0];
    List<WeatherCondition> allConditions;

    if (json['conditions'] != null) {
      allConditions = (json['conditions'] as List).map((c) => WeatherCondition.values[c as int]).toList();
    } else {
      allConditions = [primaryCondition];
    }

    return WeatherInfo(condition: primaryCondition, conditions: allConditions, temperature: json['temperature']?.toDouble(), notes: json['notes']);
  }

  String get conditionLabel {
    if (conditions.length == 1) {
      return _getConditionLabel(conditions.first);
    }
    return conditions.map((c) => _getConditionLabel(c)).join(', ');
  }

  static String _getConditionLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.rainy:
        return 'Rainy';
      case WeatherCondition.snowy:
        return 'Snowy';
      case WeatherCondition.windy:
        return 'Windy';
      case WeatherCondition.foggy:
        return 'Foggy';
    }
  }
}

class RouteModel {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<RoutePoint> routePoints; // Using RoutePoint
  final double totalDistance; // in meters
  final Duration totalDuration;
  final Duration totalBreakTime; // total break time
  final List<LatLng> exploredAreas;
  final List<RouteWaypoint> waypoints; // Photo waypoints
  final WeatherInfo? weather; // Weather information
  final int? rating; // rating from 1-5
  final double totalAscent; // Total ascent (meters)
  final double totalDescent; // Total descent (meters)

  RouteModel({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    required this.routePoints,
    required this.totalDistance,
    required this.totalDuration,
    this.totalBreakTime = Duration.zero,
    required this.exploredAreas,
    this.waypoints = const [],
    this.weather,
    this.rating,
    this.totalAscent = 0.0,
    this.totalDescent = 0.0,
  });

  /// Average speed (km/h)
  double get averageSpeed {
    if (totalDuration.inSeconds == 0) return 0.0;
    // Calculate moving duration by subtracting break time
    final movingDuration = totalDuration - totalBreakTime;
    if (movingDuration.inSeconds == 0) return 0.0;
    return (totalDistance / 1000) / (movingDuration.inSeconds / 3600);
  }

  String get formattedAverageSpeed {
    return '${averageSpeed.toStringAsFixed(1)} km/h';
  }

  String get formattedDistance {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${totalDistance.toStringAsFixed(0)} m';
    }
  }

  String get formattedDuration {
    int hours = totalDuration.inHours;
    int minutes = totalDuration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedBreakTime {
    int hours = totalBreakTime.inHours;
    int minutes = totalBreakTime.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedAscent {
    return '↗ ${totalAscent.toStringAsFixed(0)}m';
  }

  String get formattedDescent {
    return '↘ ${totalDescent.toStringAsFixed(0)}m';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'routePoints': routePoints.map((point) => point.toJson()).toList(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inSeconds,
      'totalBreakTime': totalBreakTime.inSeconds,
      'exploredAreas': exploredAreas.map((point) => [point.latitude, point.longitude]).toList(),
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'weather': weather?.toJson(),
      'rating': rating,
      'totalAscent': totalAscent,
      'totalDescent': totalDescent,
    };
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      routePoints: (json['routePoints'] as List).map((point) {
        // Eski format desteği için kontrol
        if (point is List) {
          // Eski format: [lat, lng]
          return RoutePoint(position: LatLng(point[0], point[1]), altitude: 0.0, timestamp: DateTime.now());
        } else if (point is String) {
          // Çok eski format: "lat,lng"
          final parts = point.split(',');
          return RoutePoint(position: LatLng(double.parse(parts[0]), double.parse(parts[1])), altitude: 0.0, timestamp: DateTime.now());
        } else if (point is Map<String, dynamic>) {
          // Yeni format: RoutePoint JSON
          return RoutePoint.fromJson(point);
        } else {
          // Fallback
          return RoutePoint(position: const LatLng(0, 0), altitude: 0.0, timestamp: DateTime.now());
        }
      }).toList(),
      totalDistance: json['totalDistance'].toDouble(),
      totalDuration: Duration(seconds: json['totalDuration']),
      totalBreakTime: Duration(seconds: json['totalBreakTime'] ?? 0),
      exploredAreas: (json['exploredAreas'] as List).map((point) {
        if (point is List) {
          // Yeni format: [lat, lng]
          return LatLng(point[0], point[1]);
        } else if (point is String) {
          // Eski format: "lat,lng"
          final parts = point.split(',');
          return LatLng(double.parse(parts[0]), double.parse(parts[1]));
        } else {
          // Fallback
          return const LatLng(0, 0);
        }
      }).toList(),
      waypoints: json['waypoints'] != null ? (json['waypoints'] as List).map((w) => RouteWaypoint.fromJson(w)).toList() : [],
      weather: json['weather'] != null ? WeatherInfo.fromJson(json['weather']) : null,
      rating: json['rating'],
      totalAscent: json['totalAscent']?.toDouble() ?? 0.0,
      totalDescent: json['totalDescent']?.toDouble() ?? 0.0,
    );
  }
}
