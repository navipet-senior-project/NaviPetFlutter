import 'package:flutter/material.dart' show Colors;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/app_theme.dart';
import 'navigation_models.dart';

/// Builds a complete camera configuration for a route, replacing any padding
/// left behind by the place sheet before Mapbox calculates the fit.
CameraOptions routeCameraOptions({required double bottomInset}) =>
    CameraOptions(
      bearing: 0,
      pitch: 0,
      padding: MbxEdgeInsets(
        top: 140,
        left: 48,
        bottom: bottomInset,
        right: 48,
      ),
    );

/// Everything the flow needs from the map, and nothing else.
abstract interface class NaviMapController {
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  });

  Future<void> showRoute(
    RoutePlan plan, {
    required NavigationCoordinate origin,
    required NaviDestination destination,
    required double bottomInset,
  });

  Future<void> followUser(NavigationCoordinate coordinate, {double? bearing});

  Future<void> clear();
}

class MapboxNaviMapController implements NaviMapController {
  MapboxNaviMapController({
    required MapboxMap map,
    required PolylineAnnotationManager routes,
    required PointAnnotationManager markers,
  }) : // Initializing formals would force the private field names into the
       // public constructor signature, making it unusable from other
       // libraries. Same resolution as HttpCampusSearchGateway.
       // ignore: prefer_initializing_formals
       _map = map,
       // ignore: prefer_initializing_formals
       _routes = routes,
       // ignore: prefer_initializing_formals
       _markers = markers;

  final MapboxMap _map;
  final PolylineAnnotationManager _routes;
  final PointAnnotationManager _markers;

  @override
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  }) async {
    await clear();
    await _markers.create(_marker(coordinate, label));
    await _map.easeTo(
      CameraOptions(
        center: _point(coordinate),
        zoom: 17,
        padding: MbxEdgeInsets(
          top: 120,
          left: 40,
          bottom: bottomInset,
          right: 40,
        ),
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  Future<void> showRoute(
    RoutePlan plan, {
    required NavigationCoordinate origin,
    required NaviDestination destination,
    required double bottomInset,
  }) async {
    await clear();

    // Alternates first so the selected route draws on top of them.
    for (var index = 0; index < plan.routes.length; index++) {
      if (index == plan.selectedIndex) continue;
      await _routes.create(_line(plan.routes[index], selected: false));
    }
    await _routes.create(_line(plan.selected, selected: true));

    await _markers.create(_marker(origin, 'Start'));
    await _markers.create(_marker(destination.coordinate, destination.name));

    final coordinates = plan.selected.coordinates;
    if (coordinates.isEmpty) return;
    final camera = await _map.cameraForCoordinatesPadding(
      coordinates.map(_point).toList(),
      routeCameraOptions(bottomInset: bottomInset),
      null,
      17,
      null,
    );
    await _map.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  @override
  Future<void> followUser(
    NavigationCoordinate coordinate, {
    double? bearing,
  }) async {
    await _map.easeTo(
      CameraOptions(
        center: _point(coordinate),
        zoom: 17.5,
        pitch: 0,
        bearing: bearing != null && bearing >= 0 ? bearing : 0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  @override
  Future<void> clear() async {
    await _routes.deleteAll();
    await _markers.deleteAll();
  }

  PolylineAnnotationOptions _line(
    NavigationRoute route, {
    required bool selected,
  }) => PolylineAnnotationOptions(
    geometry: LineString(
      coordinates: route.coordinates
          .map((point) => Position(point.longitude, point.latitude))
          .toList(),
    ),
    // Navy keeps the route legible over the light campus basemap; yellow is
    // reserved for the primary action and the selected marker.
    lineColor: selected
        ? AppColors.navy.toARGB32()
        : AppColors.faint.toARGB32(),
    lineBorderColor: Colors.white.toARGB32(),
    lineBorderWidth: selected ? 2 : 1,
    lineWidth: selected ? 7 : 5,
    lineJoin: LineJoin.ROUND,
  );

  PointAnnotationOptions _marker(NavigationCoordinate at, String label) =>
      PointAnnotationOptions(
        geometry: _point(at),
        textField: label,
        textOffset: [0, -1.8],
        textColor: AppColors.navy.toARGB32(),
        textHaloColor: Colors.white.toARGB32(),
        textHaloWidth: 2,
        textSize: 13,
      );

  Point _point(NavigationCoordinate at) =>
      Point(coordinates: Position(at.longitude, at.latitude));
}
