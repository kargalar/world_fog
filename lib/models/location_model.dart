import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Konum bilgilerini tutan model sınıfı
class LocationModel {
  final LatLng position;
  final double? bearing;
  final double accuracy;
  final double? altitude; // Yükseklik (metre)
  final DateTime timestamp;

  const LocationModel({required this.position, this.bearing, required this.accuracy, this.altitude, required this.timestamp});

  LocationModel copyWith({LatLng? position, double? bearing, double? accuracy, double? altitude, DateTime? timestamp}) {
    return LocationModel(position: position ?? this.position, bearing: bearing ?? this.bearing, accuracy: accuracy ?? this.accuracy, altitude: altitude ?? this.altitude, timestamp: timestamp ?? this.timestamp);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationModel && other.position == position && other.bearing == bearing && other.accuracy == accuracy && other.altitude == altitude && other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return position.hashCode ^ bearing.hashCode ^ accuracy.hashCode ^ altitude.hashCode ^ timestamp.hashCode;
  }

  @override
  String toString() {
    return 'LocationModel(position: $position, bearing: $bearing, accuracy: $accuracy, altitude: $altitude, timestamp: $timestamp)';
  }
}

/// Konum izni durumlarını tutan enum
enum LocationPermissionStatus { granted, denied, deniedForever, unknown }

/// Konum servisi durumunu tutan model
class LocationServiceStatus {
  final bool isEnabled;
  final LocationPermissionStatus permissionStatus;
  final String? errorMessage;

  const LocationServiceStatus({required this.isEnabled, required this.permissionStatus, this.errorMessage});

  bool get isAvailable => isEnabled && permissionStatus == LocationPermissionStatus.granted;

  LocationServiceStatus copyWith({bool? isEnabled, LocationPermissionStatus? permissionStatus, String? errorMessage}) {
    return LocationServiceStatus(isEnabled: isEnabled ?? this.isEnabled, permissionStatus: permissionStatus ?? this.permissionStatus, errorMessage: errorMessage ?? this.errorMessage);
  }

  @override
  String toString() {
    return 'LocationServiceStatus(isEnabled: $isEnabled, permissionStatus: $permissionStatus, errorMessage: $errorMessage)';
  }
}
