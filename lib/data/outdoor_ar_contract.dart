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

/// The route as Unity accepts it, or null when it cannot be sent honestly:
/// fewer than 2 points, or any point that is not a real WGS84 coordinate.
/// Nearly straight intermediate points are dropped, preserving first and last
/// points and every turn over 10 degrees. A route with more than
/// [outdoorRouteMaxWaypoints] significant points is omitted rather than cut.
List<NavigationCoordinate>? outdoorRouteWaypoints(
  List<NavigationCoordinate> route,
) {
  bool valid(NavigationCoordinate c) =>
      c.latitude.isFinite &&
      c.longitude.isFinite &&
      c.latitude.abs() <= 90 &&
      c.longitude.abs() <= 180;
  if (route.length < 2 || !route.every(valid)) return null;

  bool nearlyCollinear(
    NavigationCoordinate a,
    NavigationCoordinate b,
    NavigationCoordinate c,
  ) {
    final lonScale = math.cos(b.latitude * math.pi / 180);
    final ax = (b.longitude - a.longitude) * lonScale;
    final ay = b.latitude - a.latitude;
    final bx = (c.longitude - b.longitude) * lonScale;
    final by = c.latitude - b.latitude;
    final dot = ax * bx + ay * by;
    final cross = ax * by - ay * bx;
    if ((ax == 0 && ay == 0) || (bx == 0 && by == 0)) return true;
    if (dot <= 0) return false;
    if (cross == 0) return true;
    return math.atan2(cross.abs(), dot) <= math.pi / 18;
  }

  final kept = <NavigationCoordinate>[];
  for (final point in route) {
    kept.add(point);
    while (kept.length >= 3 &&
        nearlyCollinear(kept[kept.length - 3], kept[kept.length - 2], point)) {
      kept.removeAt(kept.length - 2);
    }
  }
  return kept.length <= outdoorRouteMaxWaypoints ? kept : null;
}
