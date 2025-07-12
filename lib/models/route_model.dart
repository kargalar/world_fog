import 'package:latlong2/latlong.dart';

class RouteModel {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final List<LatLng> routePoints;
  final double totalDistance; // metre cinsinden
  final Duration totalDuration;
  final List<LatLng> exploredAreas;

  RouteModel({required this.id, required this.name, required this.startTime, this.endTime, required this.routePoints, required this.totalDistance, required this.totalDuration, required this.exploredAreas});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'routePoints': routePoints.map((point) => '${point.latitude},${point.longitude}').toList(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inMilliseconds,
      'exploredAreas': exploredAreas.map((area) => '${area.latitude},${area.longitude}').toList(),
    };
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      routePoints: (json['routePoints'] as List<dynamic>).map((point) {
        final coords = point.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList(),
      totalDistance: json['totalDistance'].toDouble(),
      totalDuration: Duration(milliseconds: json['totalDuration']),
      exploredAreas: (json['exploredAreas'] as List<dynamic>).map((area) {
        final coords = area.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList(),
    );
  }

  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.toStringAsFixed(0)} m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(2)} km';
    }
  }

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}s ${minutes}d ${seconds}sn';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds}sn';
    } else {
      return '${seconds}sn';
    }
  }
}
