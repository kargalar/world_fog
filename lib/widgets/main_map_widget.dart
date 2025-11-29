import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../utils/app_strings.dart';

/// Ana harita widget'ı
class MainMapWidget extends StatelessWidget {
  const MainMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LocationViewModel, MapViewModel, RouteViewModel>(
      builder: (context, locationVM, mapVM, routeVM, child) {
        final currentLocation = locationVM.currentLocation;

        if (currentLocation == null) {
          return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text(AppStrings.gettingLocation)]),
          );
        }

        return GoogleMap(
          initialCameraPosition: CameraPosition(target: currentLocation.position, zoom: mapVM.zoom),
          onMapCreated: (GoogleMapController controller) {
            mapVM.setMapController(controller);
          },
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
          markers: _buildMarkers(currentLocation.position, routeVM, mapVM),
          polylines: _buildPolylines(routeVM, mapVM),
          polygons: _buildGridPolygons(mapVM),
        );
      },
    );
  }

  /// Marker'ları oluştur
  Set<Marker> _buildMarkers(LatLng currentPosition, RouteViewModel routeVM, MapViewModel mapVM) {
    final markers = <Marker>{};

    // Mevcut konum markeri
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Konumunuz'),
      ),
    );

    // Rota başlangıç markeri
    if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_start'),
          position: routeVM.currentRoutePoints.first.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Başlangıç'),
        ),
      );
    }

    return markers;
  }

  /// Polyline'ları oluştur
  Set<Polyline> _buildPolylines(RouteViewModel routeVM, MapViewModel mapVM) {
    final polylines = <Polyline>{};

    // Geçmiş rotalar
    if (mapVM.showPastRoutes && routeVM.pastRoutes.isNotEmpty) {
      for (int i = 0; i < routeVM.pastRoutes.length; i++) {
        final route = routeVM.pastRoutes[i];
        polylines.add(Polyline(polylineId: PolylineId('past_route_$i'), points: route.routePoints.map((point) => point.position).toList(), color: Colors.yellow, width: 4));
      }
    }

    // Mevcut rota
    if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty) {
      polylines.add(Polyline(polylineId: const PolylineId('current_route'), points: routeVM.currentRoutePoints.map((point) => point.position).toList(), color: Colors.red, width: 4));
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

        polygons.add(Polygon(polygonId: PolygonId('grid_$index'), points: [LatLng(minLat, minLng), LatLng(maxLat, minLng), LatLng(maxLat, maxLng), LatLng(minLat, maxLng)], fillColor: Colors.blue.withOpacity(0.2), strokeColor: Colors.blue.withOpacity(0.5), strokeWidth: 1));
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
          right: 16,
          bottom: 20,
          child: Column(
            children: [
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
                backgroundColor: mapVM.isFollowingLocation ? Colors.blue : Colors.white,
                iconColor: mapVM.isFollowingLocation ? Colors.white : Colors.grey,
                tooltip: AppStrings.followMyLocation,
              ),

              const SizedBox(height: 8),

              // Past routes button
              _buildControlButton(
                icon: mapVM.showPastRoutes ? Icons.visibility_off : Icons.visibility,
                onPressed: () => mapVM.togglePastRoutes(),
                backgroundColor: mapVM.showPastRoutes ? Colors.orange : Colors.white,
                iconColor: mapVM.showPastRoutes ? Colors.white : Colors.grey,
                tooltip: AppStrings.pastRoutes,
              ),

              const SizedBox(height: 8),

              // Profile button
              _buildControlButton(
                icon: Icons.person,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                backgroundColor: Colors.white,
                iconColor: Colors.grey,
                tooltip: AppStrings.profileAndRouteHistory,
              ),

              const SizedBox(height: 8),

              // Settings button
              _buildControlButton(
                icon: Icons.settings,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(onRadiusChanged: (newRadius) => mapVM.updateExplorationRadius(newRadius), onOpacityChanged: (newOpacity) => mapVM.updateAreaOpacity(newOpacity)),
                  ),
                ),
                backgroundColor: Colors.white,
                iconColor: Colors.grey,
                tooltip: AppStrings.settings,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed, required Color backgroundColor, required Color iconColor, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
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
