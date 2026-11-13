import 'navigation_models.dart';
import 'route_progress.dart';

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
/// shows direction-only guidance instead of claiming to follow a route.
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

/// Points closer than this to the last kept one add nothing to the walk.
const outdoorRouteMinSpacingMeters = 5.0;

/// The route as Unity accepts it, or null when it cannot be sent honestly:
/// fewer than 2 points, or any point that is not a real WGS84 coordinate.
/// Near-duplicate points are dropped (first and last always stay). If a very
/// long route still exceeds [outdoorRouteMaxWaypoints] the spacing widens
/// until it fits, so the whole path is kept rather than cut short.
List<NavigationCoordinate>? outdoorRouteWaypoints(
  List<NavigationCoordinate> route,
) {
  bool valid(NavigationCoordinate c) =>
      c.latitude.isFinite &&
      c.longitude.isFinite &&
      c.latitude.abs() <= 90 &&
      c.longitude.abs() <= 180;
  if (route.length < 2 || !route.every(valid)) return null;

  for (var spacing = outdoorRouteMinSpacingMeters; ; spacing *= 2) {
    final kept = [route.first];
    for (final point in route.skip(1).take(route.length - 2)) {
      if (distanceMeters(kept.last, point) >= spacing) kept.add(point);
    }
    kept.add(route.last);
    if (kept.length <= outdoorRouteMaxWaypoints) return kept;
  }
}
