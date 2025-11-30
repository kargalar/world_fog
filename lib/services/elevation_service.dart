import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Yükseklik verilerini almak için servis sınıfı
class ElevationService {
  static const String _baseUrl = 'https://api.open-elevation.com/api/v1/lookup';

  /// Belirli koordinatlar için yükseklik verilerini al
  static Future<double?> getElevation(LatLng position) async {
    try {
      final url = Uri.parse('$_baseUrl?locations=${position.latitude},${position.longitude}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['elevation']?.toDouble();
        }
      }
    } catch (e) {
      // Hata durumunda null döndür
    }
    return null;
  }

  /// Birden fazla koordinat için yükseklik verilerini al
  static Future<List<double?>> getElevations(List<LatLng> positions) async {
    if (positions.isEmpty) return [];

    try {
      final locations = positions.map((p) => '${p.latitude},${p.longitude}').join('|');
      final url = Uri.parse('$_baseUrl?locations=$locations');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          return (data['results'] as List).map<double?>((result) => result['elevation']?.toDouble()).toList();
        }
      }
    } catch (e) {
      // Hata durumunda null listesi döndür
    }
    return List.filled(positions.length, null);
  }
}
