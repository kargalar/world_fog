import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../models/route_model.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../pages/profile_page.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import 'waypoint_dialog.dart';

/// Custom marker icons cache
class MarkerIcons {
  static BitmapDescriptor? currentLocation;
  static BitmapDescriptor? routeStart;
  static BitmapDescriptor? routeEnd;
  static BitmapDescriptor? breakPoint;
  static BitmapDescriptor? scenery;
  static BitmapDescriptor? fountain;
  static BitmapDescriptor? junction;
  static BitmapDescriptor? waterfall;
  static BitmapDescriptor? other;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    currentLocation = await _createCustomMarker(Icons.my_location, AppColors.blue, 40);
    routeStart = await _createCustomMarker(Icons.flag, AppColors.green, 45);
    routeEnd = await _createCustomMarker(Icons.flag_outlined, AppColors.red, 45);
    breakPoint = await _createCustomMarker(Icons.coffee, AppColors.brown, 40);
    scenery = await _createCustomMarker(Icons.landscape, AppColors.greenShade700, 40);
    fountain = await _createCustomMarker(Icons.water_drop, AppColors.blue, 40);
    junction = await _createCustomMarker(Icons.alt_route, AppColors.orange, 40);
    waterfall = await _createCustomMarker(Icons.water, AppColors.cyan, 40);
    other = await _createCustomMarker(Icons.location_on, AppColors.purple, 40);

    _initialized = true;
  }

  static Future<BitmapDescriptor> _createCustomMarker(IconData icon, Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final double markerSize = size;
    final double iconSize = size * 0.55;

    // Draw shadow
    canvas.drawCircle(Offset(markerSize / 2 + 1, markerSize / 2 + 2), markerSize / 2 - 2, shadowPaint);

    // Draw circle background
    canvas.drawCircle(Offset(markerSize / 2, markerSize / 2), markerSize / 2 - 2, paint);

    // Draw white border
    final borderPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(markerSize / 2, markerSize / 2), markerSize / 2 - 2, borderPaint);

    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontSize: iconSize, fontFamily: icon.fontFamily, package: icon.fontPackage, color: AppColors.white),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((markerSize - textPainter.width) / 2, (markerSize - textPainter.height) / 2));

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(markerSize.toInt(), markerSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static BitmapDescriptor getWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return scenery ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case WaypointType.fountain:
        return fountain ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case WaypointType.junction:
        return junction ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case WaypointType.waterfall:
        return waterfall ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      case WaypointType.breakPoint:
        return breakPoint ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case WaypointType.other:
        return other ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }
}

/// Ana harita widget'ı
class MainMapWidget extends StatefulWidget {
  const MainMapWidget({super.key});

  @override
  State<MainMapWidget> createState() => _MainMapWidgetState();
}

class _MainMapWidgetState extends State<MainMapWidget> {
  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  Future<void> _initializeMarkers() async {
    await MarkerIcons.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationViewModel, MapViewModel, RouteViewModel>(
      builder: (context, locationVM, mapVM, routeVM, child) {
        final currentLocation = locationVM.currentLocation;

        // Konum yoksa son bilinen konumu veya varsayılan konumu kullan
        final mapCenter = currentLocation?.position ?? mapVM.lastKnownLocation;
        final hasCurrentLocation = currentLocation != null;

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: mapCenter, zoom: mapVM.zoom),
              onMapCreated: (GoogleMapController controller) {
                mapVM.setMapController(controller);
              },
              mapType: mapVM.mapType,
              myLocationEnabled: false, // Kendi markerımızı kullanacağız
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(5.0, 18.0),
              onCameraMove: (CameraPosition position) {
                // Kullanıcı haritayı manuel hareket ettirirse otomatik takibi kapat
                if (mapVM.isFollowingLocation) {
                  mapVM.setLocationFollowing(false);
                }
              },
              markers: _buildMarkers(context, currentLocation?.position, routeVM, mapVM),
              polylines: _buildPolylines(routeVM, mapVM),
              polygons: _buildGridPolygons(mapVM),
            ),
            // Konum alınıyorsa üstte gösterge göster
            if (!hasCurrentLocation && !locationVM.isLocationAvailable)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () async {
                    // Önce izin iste, sonra konum servislerini aç
                    await Location().requestPermission();
                    await Location().requestService();
                  },
                  child: Card(
                    color: AppColors.orange.withValues(alpha: 0.9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off, color: AppColors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(AppStrings.locationDisabled, style: const TextStyle(color: AppColors.white, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Marker'ları oluştur
  Set<Marker> _buildMarkers(BuildContext context, LatLng? currentPosition, RouteViewModel routeVM, MapViewModel mapVM) {
    final markers = <Marker>{};

    // Mevcut konum markeri (sadece konum varsa göster)
    if (currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentPosition,
          icon: MarkerIcons.currentLocation ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your Location'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    // Rota başlangıç markeri
    if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_start'),
          position: routeVM.currentRoutePoints.first.position,
          icon: MarkerIcons.routeStart ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    // Waypoint markerları
    if (routeVM.isTracking) {
      for (final waypoint in routeVM.currentWaypoints) {
        markers.add(
          Marker(
            markerId: MarkerId('waypoint_${waypoint.id}'),
            position: waypoint.position,
            icon: MarkerIcons.getWaypointIcon(waypoint.type),
            infoWindow: InfoWindow(title: waypoint.typeLabel),
            anchor: const Offset(0.5, 0.5),
            onTap: () {
              _showWaypointDetail(context, waypoint, routeVM);
            },
          ),
        );
      }
    }

    return markers;
  }

  void _showWaypointDetail(BuildContext context, RouteWaypoint waypoint, RouteViewModel routeVM) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => WaypointDetailSheet(
        waypoint: waypoint,
        onDelete: () {
          Navigator.pop(context);
          routeVM.removeWaypoint(waypoint.id);
        },
      ),
    );
  }

  /// Polyline'ları oluştur
  Set<Polyline> _buildPolylines(RouteViewModel routeVM, MapViewModel mapVM) {
    final polylines = <Polyline>{};

    // Geçmiş rotalar
    if (mapVM.showPastRoutes && routeVM.pastRoutes.isNotEmpty) {
      for (int i = 0; i < routeVM.pastRoutes.length; i++) {
        final route = routeVM.pastRoutes[i];
        polylines.add(Polyline(polylineId: PolylineId('past_route_$i'), points: route.routePoints.map((point) => point.position).toList(), color: AppColors.yellow, width: 4));
      }
    }

    // Mevcut rota
    if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty) {
      polylines.add(Polyline(polylineId: const PolylineId('current_route'), points: routeVM.currentRoutePoints.map((point) => point.position).toList(), color: AppColors.red, width: 4));
    }

    return polylines;
  }

  /// Grid polygon'larını oluştur
  Set<Polygon> _buildGridPolygons(MapViewModel mapVM) {
    final polygons = <Polygon>{};
    const gridSizeDegrees = 0.0032;

    int index = 0;
    for (final gridKey in mapVM.exploredGrids) {
      final parts = gridKey.split('_');
      if (parts.length != 2) continue;

      try {
        final latGrid = int.parse(parts[0]);
        final lngGrid = int.parse(parts[1]);

        final minLat = latGrid * gridSizeDegrees;
        final maxLat = (latGrid + 1) * gridSizeDegrees;
        final minLng = lngGrid * gridSizeDegrees;
        final maxLng = (lngGrid + 1) * gridSizeDegrees;

        polygons.add(Polygon(polygonId: PolygonId('grid_$index'), points: [LatLng(minLat, minLng), LatLng(maxLat, minLng), LatLng(maxLat, maxLng), LatLng(minLat, maxLng)], fillColor: AppColors.blue.withValues(alpha: 0.2), strokeColor: AppColors.blue.withValues(alpha: 0.5), strokeWidth: 1));
        index++;
      } catch (e) {
        continue;
      }
    }

    return polygons;
  }
}

/// Harita kontrol butonları widget'ı
class MapControlButtons extends StatelessWidget {
  const MapControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationViewModel, MapViewModel>(
      builder: (context, locationVM, mapVM, child) {
        return Positioned(
          left: 16,
          bottom: 16,
          child: Column(
            children: [
              // Map type button
              _buildControlButton(icon: _getMapTypeIcon(mapVM.mapType), onPressed: () => _showMapTypeSelector(context, mapVM), backgroundColor: AppColors.white, iconColor: AppColors.grey, tooltip: AppStrings.mapViewTitle),

              const SizedBox(height: 8),

              // Location follow button
              _buildControlButton(
                icon: mapVM.isFollowingLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
                onPressed: () {
                  if (locationVM.hasLocation) {
                    mapVM.toggleLocationFollowing();
                    if (mapVM.isFollowingLocation) {
                      mapVM.updateMapCenter(locationVM.currentPosition!);
                    }
                  }
                },
                backgroundColor: mapVM.isFollowingLocation ? AppColors.blue : AppColors.white,
                iconColor: mapVM.isFollowingLocation ? AppColors.white : AppColors.grey,
                tooltip: AppStrings.followMyLocation,
              ),

              const SizedBox(height: 8),

              // Past routes button
              _buildControlButton(
                icon: mapVM.showPastRoutes ? Icons.visibility_off : Icons.visibility,
                onPressed: () => mapVM.togglePastRoutes(),
                backgroundColor: mapVM.showPastRoutes ? AppColors.orange : AppColors.white,
                iconColor: mapVM.showPastRoutes ? AppColors.white : AppColors.grey,
                tooltip: AppStrings.pastRoutes,
              ),

              const SizedBox(height: 8),

              // Profile button
              _buildControlButton(
                icon: Icons.person,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                backgroundColor: AppColors.white,
                iconColor: AppColors.grey,
                tooltip: AppStrings.profileAndRouteHistory,
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getMapTypeIcon(MapType mapType) {
    switch (mapType) {
      case MapType.normal:
        return Icons.map;
      case MapType.satellite:
        return Icons.satellite;
      case MapType.terrain:
        return Icons.terrain;
      case MapType.hybrid:
        return Icons.layers;
      default:
        return Icons.map;
    }
  }

  void _showMapTypeSelector(BuildContext context, MapViewModel mapVM) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.mapViewTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMapTypeOption(context, mapVM, MapType.normal, AppStrings.normalMap, Icons.map),
                _buildMapTypeOption(context, mapVM, MapType.satellite, AppStrings.satelliteMap, Icons.satellite),
                _buildMapTypeOption(context, mapVM, MapType.terrain, AppStrings.terrainMap, Icons.terrain),
                _buildMapTypeOption(context, mapVM, MapType.hybrid, AppStrings.hybridMap, Icons.layers),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(BuildContext context, MapViewModel mapVM, MapType type, String label, IconData icon) {
    final isSelected = mapVM.mapType == type;
    return InkWell(
      onTap: () {
        mapVM.setMapType(type);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : AppColors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : AppColors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: isSelected ? Theme.of(context).primaryColor : AppColors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).primaryColor : AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed, required Color backgroundColor, required Color iconColor, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
          iconSize: 20,
        ),
      ),
    );
  }
}
