import 'dart:math' as math;

import 'navigation_models.dart';

/// Build flag: `--dart-define=NAVIPET_OUTDOOR_AR=true`. Set it only when the
/// private Unity library includes the outdoor Geospatial scene. Off, the
/// outdoor AR control explains that guidance is unavailable and opens nothing.
const outdoorArBuildEnabled = bool.fromEnvironment('NAVIPET_OUTDOOR_AR');

/// One outdoor ARCore Geospatial session toward the active route's
/// destination. It rides the indoor AR channel and gets the same result
/// envelope back; `mode` tells Unity which scene to run.
///
/// Carries no MultiSet token and no Google credential: Unity authorises with
/// the ARCore API itself.
///
/// [route] is the active walking route's polyline. It is sent only when it is
/// a valid path Unity will accept; otherwise [waypoints] is null and Unity
/// must not claim route-following guidance.
class OutdoorArRequest {
  OutdoorArRequest.to(
    NaviDestination destination, {
    List<NavigationCoordinate> route = const [],
  }) : name = destination.name,
       coordinate = destination.routingCoordinate,
       waypoints = outdoorRouteWaypoints(route);

  static const schemaVersion = 2;
  static const outdoorMode = 'outdoor';

  final String name;

  /// WGS84, the point the walking route itself ends at.
  final NavigationCoordinate coordinate;

  /// Ordered start to destination, or null when there is no usable route.
  final List<NavigationCoordinate>? waypoints;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'mode': outdoorMode,
    'destination': {
      'name': name,
      'latitude': coordinate.latitude,
      'longitude': coordinate.longitude,
    },
    // The host shows Google's ARCore notice and launches only after consent.
    'dataUseAccepted': true,
    if (waypoints != null)
      'route': {
        'waypoints': [
          for (final point in waypoints!)
            {'latitude': point.latitude, 'longitude': point.longitude},
        ],
      },
  };
}

/// Unity rejects fewer than 2 or more than this many waypoints.
const outdoorRouteMaxWaypoints = 1000;

/// Maximum perpendicular error for the first route simplification pass.
const outdoorRouteToleranceMeters = 2.0;

/// The route as Unity accepts it, or null when it cannot be sent honestly:
/// fewer than 2 points, or any point that is not a real WGS84 coordinate.
/// Douglas-Peucker simplification preserves endpoints and route order. Its
/// tolerance widens from [outdoorRouteToleranceMeters] only to meet the cap.
List<NavigationCoordinate>? outdoorRouteWaypoints(
  List<NavigationCoordinate> route,
) {
  bool valid(NavigationCoordinate c) =>
      c.latitude.isFinite &&
      c.longitude.isFinite &&
      c.latitude.abs() <= 90 &&
      c.longitude.abs() <= 180;
  if (route.length < 2 || !route.every(valid)) return null;

  final first = route.first;
  final metersPerDegree = 111195 * math.cos(first.latitude * math.pi / 180);
  final x = [
    for (final point in route)
      (point.longitude - first.longitude) * metersPerDegree,
  ];
  final y = [
    for (final point in route) (point.latitude - first.latitude) * 111195,
  ];

  List<NavigationCoordinate> simplify(double tolerance) {
    final keep = List<bool>.filled(route.length, false)
      ..[0] = true
      ..[route.length - 1] = true;
    final segments = <int>[0, route.length - 1];
    while (segments.isNotEmpty) {
      final end = segments.removeLast();
      final start = segments.removeLast();
      final dx = x[end] - x[start];
      final dy = y[end] - y[start];
      final lengthSquared = dx * dx + dy * dy;
      var maxDistance = tolerance;
      var maxIndex = -1;
      for (var i = start + 1; i < end; i++) {
        final fraction = lengthSquared == 0
            ? 0.0
            : (((x[i] - x[start]) * dx + (y[i] - y[start]) * dy) /
                      lengthSquared)
                  .clamp(0.0, 1.0);
        final offsetX = x[i] - x[start] - dx * fraction;
        final offsetY = y[i] - y[start] - dy * fraction;
        final distance = math.sqrt(offsetX * offsetX + offsetY * offsetY);
        if (distance > maxDistance) {
          maxDistance = distance;
          maxIndex = i;
        }
      }
      if (maxIndex >= 0) {
        keep[maxIndex] = true;
        segments
          ..add(start)
          ..add(maxIndex)
          ..add(maxIndex)
          ..add(end);
      }
    }
    return [
      for (var i = 0; i < route.length; i++)
        if (keep[i]) route[i],
    ];
  }

  for (var tolerance = outdoorRouteToleranceMeters; ; tolerance *= 2) {
    final waypoints = simplify(tolerance);
    if (waypoints.length <= outdoorRouteMaxWaypoints) return waypoints;
  }
}
