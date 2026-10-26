import 'package:flutter/material.dart' show Colors;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/app_theme.dart';
import 'navigation_models.dart';

/// Visual settings shared by preview and live guidance.
const selectedRouteWidth = 14.0;
const guidanceRouteWidth = 16.0;
const userArrowSize = 64.0;

PointAnnotationOptions userArrowOptions(
  NavigationCoordinate position, {
  double? bearing,
}) => PointAnnotationOptions(
  geometry: Point(coordinates: Position(position.longitude, position.latitude)),
  textField: '▲',
  textSize: userArrowSize,
  textRotate: bearing != null && bearing >= 0 ? bearing : 0,
  textColor: AppColors.amber.toARGB32(),
  textHaloColor: AppColors.navy.toARGB32(),
  textHaloWidth: 5,
);

PointAnnotationOptions destinationPinOptions(
  NavigationCoordinate destination,
) => PointAnnotationOptions(
  geometry: Point(
    coordinates: Position(destination.longitude, destination.latitude),
  ),
  textField: '◆',
  textSize: 42,
  textColor: AppColors.amber.toARGB32(),
  textHaloColor: AppColors.navy.toARGB32(),
  textHaloWidth: 4,
);

/// Builds a complete camera configuration for a route, replacing any padding
/// left behind by the place sheet before Mapbox calculates the fit.
CameraOptions routeCameraOptions({
  required double bottomInset,
  double pitch = 0,
}) => CameraOptions(
  bearing: 0,
  pitch: pitch,
  padding: MbxEdgeInsets(top: 140, left: 48, bottom: bottomInset, right: 48),
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

  Future<void> showGuidance(
    List<NavigationCoordinate> remaining, {
    required NavigationCoordinate position,
    required NaviDestination destination,
    double? bearing,
  });

  Future<void> clear();
}

class MapboxNaviMapController implements NaviMapController {
  MapboxNaviMapController({
    required MapboxMap map,
    required PolylineAnnotationManager routes,
    required PointAnnotationManager markers,
    required PointAnnotationManager arrowMarkers,
    required PolygonAnnotationManager footprints,
  }) : // Initializing formals would force the private field names into the
       // public constructor signature, making it unusable from other
       // libraries. Same resolution as HttpCampusSearchGateway.
       // ignore: prefer_initializing_formals
       _map = map,
       // ignore: prefer_initializing_formals
       _routes = routes,
       // ignore: prefer_initializing_formals
       _markers = markers,
       // ignore: prefer_initializing_formals
       _arrowMarkers = arrowMarkers,
       // ignore: prefer_initializing_formals
       _footprints = footprints;

  final MapboxMap _map;
  final PolylineAnnotationManager _routes;
  final PointAnnotationManager _markers;
  final PointAnnotationManager _arrowMarkers;
  final PolygonAnnotationManager _footprints;
  bool _guidanceActive = false;
  double _pitch = 0;
  int _pitchRevision = 0;

  /// Updates the camera pitch used by the live map and all future previews.
  /// Keeping it here prevents route fitting from silently undoing 3D mode.
  Future<void> setPitch(double pitch) async {
    final revision = ++_pitchRevision;
    _pitch = pitch;
    final camera = await _map.getCameraState();
    if (revision != _pitchRevision) return;
    await _map.easeTo(
      CameraOptions(
        center: camera.center,
        padding: camera.padding,
        zoom: camera.zoom,
        bearing: camera.bearing,
        pitch: pitch,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

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
        pitch: _pitch,
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
    await _showDestination(destination);

    final coordinates = plan.selected.coordinates;
    if (coordinates.isEmpty) return;
    final camera = await _map.cameraForCoordinatesPadding(
      coordinates.map(_point).toList(),
      routeCameraOptions(bottomInset: bottomInset, pitch: _pitch),
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
        pitch: _pitch,
        bearing: bearing != null && bearing >= 0 ? bearing : 0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  @override
  Future<void> showGuidance(
    List<NavigationCoordinate> remaining, {
    required NavigationCoordinate position,
    required NaviDestination destination,
    double? bearing,
  }) async {
    await _clearAnnotations();
    if (!_guidanceActive) {
      _guidanceActive = true;
      await _map.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
    }
    if (remaining.length >= 2) {
      await _routes.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: remaining
                .map((point) => Position(point.longitude, point.latitude))
                .toList(),
          ),
          lineColor: AppColors.navy.toARGB32(),
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 3,
          lineWidth: guidanceRouteWidth,
          lineJoin: LineJoin.ROUND,
        ),
      );
    }
    await _showDestination(destination);
    await _arrowMarkers.create(userArrowOptions(position, bearing: bearing));
    await followUser(position, bearing: bearing);
  }

  Future<void> _showDestination(NaviDestination destination) async {
    final footprint = destination.footprint;
    if (footprint != null) {
      await _footprints.create(
        PolygonAnnotationOptions(
          geometry: Polygon(
            coordinates: [
              footprint
                  .map((point) => Position(point.longitude, point.latitude))
                  .toList(),
            ],
          ),
          fillColor: AppColors.navy.toARGB32(),
          fillOpacity: 0.18,
          fillOutlineColor: AppColors.navy.toARGB32(),
        ),
      );
    }
    await _markers.create(destinationPinOptions(destination.coordinate));
    await _markers.create(
      _marker(
        destination.coordinate,
        'Destination: ${destination.name}',
        textOffset: [0, -3.2],
      ),
    );
  }

  @override
  Future<void> clear() async {
    await _clearAnnotations();
    if (_guidanceActive) {
      _guidanceActive = false;
      await _map.location.updateSettings(
        LocationComponentSettings(enabled: true),
      );
    }
  }

  Future<void> _clearAnnotations() async {
    await _routes.deleteAll();
    await _markers.deleteAll();
    await _arrowMarkers.deleteAll();
    await _footprints.deleteAll();
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
    lineBorderWidth: selected ? 3 : 1,
    lineWidth: selected ? selectedRouteWidth : 5,
    lineJoin: LineJoin.ROUND,
  );

  PointAnnotationOptions _marker(
    NavigationCoordinate at,
    String label, {
    List<double> textOffset = const [0, -1.8],
  }) => PointAnnotationOptions(
    geometry: _point(at),
    textField: label,
    textOffset: textOffset,
    textColor: AppColors.navy.toARGB32(),
    textHaloColor: Colors.white.toARGB32(),
    textHaloWidth: 2,
    textSize: 13,
  );

  Point _point(NavigationCoordinate at) =>
      Point(coordinates: Position(at.longitude, at.latitude));
}
