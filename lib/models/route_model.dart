import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePoint {
  final LatLng position;
  final double altitude; // metre cinsinden yükseklik
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
  scenery, // Manzara
  fountain, // Çeşme
  junction, // Yol ayrımı
  waterfall, // Şelale
  breakPoint, // Mola
  other, // Diğer
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
        return 'Manzara';
      case WaypointType.fountain:
        return 'Çeşme';
      case WaypointType.junction:
        return 'Yol Ayrımı';
      case WaypointType.waterfall:
        return 'Şelale';
      case WaypointType.breakPoint:
        return 'Mola';
      case WaypointType.other:
        return 'Diğer';
    }
  }
}

/// Hava durumu bilgisi için model
enum WeatherCondition {
  sunny, // Güneşli
  cloudy, // Bulutlu
  rainy, // Yağmurlu
  snowy, // Karlı
  windy, // Rüzgarlı
  foggy, // Sisli
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
        return 'Güneşli';
      case WeatherCondition.cloudy:
        return 'Bulutlu';
      case WeatherCondition.rainy:
        return 'Yağmurlu';
      case WeatherCondition.snowy:
        return 'Karlı';
      case WeatherCondition.windy:
        return 'Rüzgarlı';
      case WeatherCondition.foggy:
        return 'Sisli';
    }
  }
}

class RouteModel {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<RoutePoint> routePoints; // RoutePoint kullanıyoruz
  final double totalDistance; // metre cinsinden
  final Duration totalDuration;
  final Duration totalBreakTime; // toplam mola süresi
  final List<LatLng> exploredAreas;
  final List<RouteWaypoint> waypoints; // Fotoğraf işaretleri
  final WeatherInfo? weather; // Hava durumu bilgisi
  final int? rating; // 1-5 arası puan
  final double totalAscent; // Toplam çıkış (metre)
  final double totalDescent; // Toplam iniş (metre)

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

  /// Ortalama hız (km/h)
  double get averageSpeed {
    if (totalDuration.inSeconds == 0) return 0.0;
    // Mola süresini çıkararak hareket süresini hesapla
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
      return '${hours}s ${minutes}dk';
    } else {
      return '${minutes}dk';
    }
  }

  String get formattedBreakTime {
    int hours = totalBreakTime.inHours;
    int minutes = totalBreakTime.inMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    } else {
      return '${minutes}dk';
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
