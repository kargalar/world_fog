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

  RouteModel({required this.id, required this.name, required this.startTime, this.endTime, required this.routePoints, required this.totalDistance, required this.totalDuration, this.totalBreakTime = Duration.zero, required this.exploredAreas});

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
    );
  }
}
