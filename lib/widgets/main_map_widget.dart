import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:provider/provider.dart';
import '../viewmodels/location_viewmodel.dart';
import '../viewmodels/map_viewmodel.dart';
import '../viewmodels/route_viewmodel.dart';
import '../models/route_model.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../utils/app_strings.dart';

import 'grid_painter_widget.dart';

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

        return FlutterMap(
          mapController: mapVM.mapController,
          options: MapOptions(
            initialCenter: currentLocation.position,
            initialZoom: mapVM.zoom,
            minZoom: 5.0,
            maxZoom: 18.0,
            onMapEvent: (event) {
              // Kullanıcı haritayı manuel hareket ettirirse otomatik takibi kapat
              if (event is MapEventMoveStart && mapVM.isFollowingLocation) {
                mapVM.setLocationFollowing(false);
              }
            },
          ),
          children: [
            // Tile Layer
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.world_fog', subdomains: const ['a', 'b', 'c', 'd']),

            // Keşfedilen gridler
            if (mapVM.exploredGrids.isNotEmpty)
              GridPainterWidget(
                exploredGrids: mapVM.exploredGrids,
                gridSizeDegrees: 0.0032, // 0.125km² için
                mapController: mapVM.mapController,
              ),

            // Aktif rota keşif alanları - Yeşil sis efekti
            // TODO: Rota için grid sistemi eklenebilir

            // Geçmiş rotalar
            if (mapVM.showPastRoutes && routeVM.pastRoutes.isNotEmpty) _buildPastRoutesLayer(routeVM.pastRoutes),

            // Mevcut rota
            if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty) _buildCurrentRouteLayer(routeVM.currentRoutePoints),

            // Marker layer
            MarkerLayer(
              markers: [
                // Mevcut konum markeri
                Marker(
                  point: currentLocation.position,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Icon(mapVM.isFollowingLocation ? Icons.navigation : Icons.my_location, color: Colors.white, size: 20),
                  ),
                ),

                // Rota başlangıç markeri
                if (routeVM.isTracking && routeVM.currentRoutePoints.isNotEmpty)
                  Marker(
                    point: routeVM.currentRoutePoints.first.position,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Geçmiş rotaları çizen layer
  Widget _buildPastRoutesLayer(List<RouteModel> routes) {
    return PolylineLayer(
      polylines: routes.map((route) {
        return Polyline(points: route.routePoints.map((point) => point.position).toList(), strokeWidth: 3.0, color: Colors.grey.withValues(alpha: 0.7));
      }).toList(),
    );
  }

  /// Mevcut rotayı çizen layer
  Widget _buildCurrentRouteLayer(List<RoutePoint> routePoints) {
    return PolylineLayer(
      polylines: [Polyline(points: routePoints.map((point) => point.position).toList(), strokeWidth: 4.0, color: Colors.red, borderStrokeWidth: 2.0, borderColor: Colors.white)],
    );
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
          bottom: 100,
          child: Column(
            children: [
              // Konum takip butonu
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
                tooltip: 'Konumumu Takip Et',
              ),

              const SizedBox(height: 8),

              // Konum durumu kontrol butonu
              _buildControlButton(icon: Icons.gps_fixed, onPressed: () => locationVM.checkLocationServiceStatus(), backgroundColor: locationVM.isLocationAvailable ? Colors.green : Colors.red, iconColor: Colors.white, tooltip: 'Konum Durumunu Kontrol Et'),

              const SizedBox(height: 8),

              // Geçmiş rotalar butonu
              _buildControlButton(
                icon: mapVM.showPastRoutes ? Icons.visibility_off : Icons.visibility,
                onPressed: () => mapVM.togglePastRoutes(),
                backgroundColor: mapVM.showPastRoutes ? Colors.orange : Colors.white,
                iconColor: mapVM.showPastRoutes ? Colors.white : Colors.grey,
                tooltip: 'Geçmiş Rotalar',
              ),

              const SizedBox(height: 8),

              // Mevcut konuma git butonu
              _buildControlButton(
                icon: Icons.my_location,
                onPressed: () {
                  if (locationVM.hasLocation) {
                    mapVM.updateMapCenter(locationVM.currentPosition!, zoom: 15.0);
                  }
                },
                backgroundColor: Colors.white,
                iconColor: Colors.grey,
                tooltip: 'Konumuma Git',
              ),

              const SizedBox(height: 8),

              // Profil butonu
              _buildControlButton(
                icon: Icons.person,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                backgroundColor: Colors.white,
                iconColor: Colors.grey,
                tooltip: 'Profil ve Rota Geçmişi',
              ),

              const SizedBox(height: 8),

              // Ayarlar butonu
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
                tooltip: 'Ayarlar',
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
          iconSize: 24,
        ),
      ),
    );
  }
}
