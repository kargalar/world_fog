import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_model.dart';

class ExplorationMapWidget extends StatefulWidget {
  final LatLng? currentPosition;
  final List<LatLng> exploredAreas;
  final List<RoutePoint> currentRoutePoints;
  final List<LatLng> currentRouteExploredAreas;
  final List<RouteModel> pastRoutes;
  final bool showPastRoutes;
  final double explorationRadius;
  final double areaOpacity;
  final bool isFollowingLocation;
  final double? currentBearing;
  final Function(GoogleMapController)? onMapCreated;

  const ExplorationMapWidget({
    super.key,
    this.currentPosition,
    required this.exploredAreas,
    required this.currentRoutePoints,
    required this.currentRouteExploredAreas,
    required this.pastRoutes,
    required this.showPastRoutes,
    required this.explorationRadius,
    required this.areaOpacity,
    required this.isFollowingLocation,
    this.currentBearing,
    this.onMapCreated,
  });

  @override
  State<ExplorationMapWidget> createState() => _ExplorationMapWidgetState();
}

class _ExplorationMapWidgetState extends State<ExplorationMapWidget> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.currentPosition ?? const LatLng(39.9334, 32.8597), zoom: 15.0),
      onMapCreated: (GoogleMapController controller) {
        if (!_controller.isCompleted) {
          _controller.complete(controller);
        }
        widget.onMapCreated?.call(controller);
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      minMaxZoomPreference: const MinMaxZoomPreference(3.0, 18.0),
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      circles: _buildCircles(),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Mevcut konum işaretçisi
    if (widget.currentPosition != null) {
      markers.add(Marker(markerId: const MarkerId('current_location'), position: widget.currentPosition!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), rotation: widget.currentBearing ?? 0));
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    // Geçmiş rotalar
    if (widget.showPastRoutes && widget.pastRoutes.isNotEmpty) {
      for (int i = 0; i < widget.pastRoutes.length; i++) {
        final route = widget.pastRoutes[i];
        polylines.add(Polyline(polylineId: PolylineId('past_route_$i'), points: route.routePoints.map((point) => point.position).toList(), color: Colors.grey.withOpacity(0.6), width: 2));
      }
    }

    // Aktif rota çizgisi
    if (widget.currentRoutePoints.length > 1) {
      polylines.add(Polyline(polylineId: const PolylineId('current_route'), points: widget.currentRoutePoints.map((point) => point.position).toList(), color: Colors.red, width: 4));
    }

    return polylines;
  }

  Set<Circle> _buildCircles() {
    final circles = <Circle>{};
    int index = 0;

    // Keşfedilen alanlar - Sis efekti (geçmiş)
    for (final area in widget.exploredAreas) {
      circles.add(Circle(circleId: CircleId('explored_$index'), center: area, radius: widget.explorationRadius, fillColor: Colors.blue.withOpacity(widget.areaOpacity * 0.6), strokeColor: Colors.blue.withOpacity(widget.areaOpacity * 0.3), strokeWidth: 1));
      index++;
    }

    // Aktif rota keşif alanları - Sis efekti
    for (final area in widget.currentRouteExploredAreas) {
      circles.add(Circle(circleId: CircleId('route_explored_$index'), center: area, radius: widget.explorationRadius, fillColor: Colors.green.withOpacity(widget.areaOpacity * 0.8), strokeColor: Colors.green.withOpacity(widget.areaOpacity * 0.4), strokeWidth: 1));
      index++;
    }

    return circles;
  }
}
