import 'dart:math' as math;

import 'navigation_models.dart';

/// A position projected onto a route, with only the geometry still ahead.
class RouteProgress {
  const RouteProgress({
    required this.remaining,
    required this.traveledMeters,
    required this.remainingMeters,
    required this.offRouteMeters,
  });

  final List<NavigationCoordinate> remaining;
  final double traveledMeters;
  final double remainingMeters;
  final double offRouteMeters;
}

double distanceMeters(NavigationCoordinate a, NavigationCoordinate b) {
  const radius = 6371000.0;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * radius * math.asin(math.sqrt(h.clamp(0, 1)));
}

bool _insideRing(
  List<NavigationCoordinate> ring,
  NavigationCoordinate position,
) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.latitude > position.latitude) != (b.latitude > position.latitude) &&
        position.longitude <
            (b.longitude - a.longitude) *
                    (position.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude) {
      inside = !inside;
    }
  }
  return inside;
}

/// Positive within a building, negative outside (including holes), zero on walls.
double signedFootprintDistanceMeters(
  BuildingFootprint footprint,
  NavigationCoordinate position,
) {
  var inside = false;
  var gap = double.infinity;
  for (final polygon in footprint.polygons) {
    if (_insideRing(polygon.first, position) &&
        !polygon.skip(1).any((hole) => _insideRing(hole, position))) {
      inside = true;
    }
    for (final ring in polygon) {
      gap = math.min(gap, projectOntoRoute(ring, position).offRouteMeters);
    }
  }
  return inside ? gap : -gap;
}

/// Distance to the occupied building area; holes remain outside.
double distanceToFootprintMeters(
  BuildingFootprint footprint,
  NavigationCoordinate position,
) => math.max(0, -signedFootprintDistanceMeters(footprint, position));

RouteProgress projectOntoRoute(
  List<NavigationCoordinate> points,
  NavigationCoordinate position, {
  double minimumProgressMeters = 0,
}) {
  if (points.length < 2) {
    return RouteProgress(
      remaining: points,
      traveledMeters: 0,
      remainingMeters: points.isEmpty
          ? 0
          : distanceMeters(position, points.last),
      offRouteMeters: double.infinity,
    );
  }

  const metersPerDegree = 111195.0;
  final lonScale = math.cos(position.latitude * math.pi / 180);
  double x(NavigationCoordinate p) =>
      (p.longitude - position.longitude) * metersPerDegree * lonScale;
  double y(NavigationCoordinate p) =>
      (p.latitude - position.latitude) * metersPerDegree;

  var bestDistance = double.infinity;
  var bestAlong = 0.0;
  var bestSegment = 0;
  var bestFraction = 0.0;
  var walked = 0.0;
  final lengths = <double>[];
  for (var i = 0; i < points.length - 1; i++) {
    final ax = x(points[i]);
    final ay = y(points[i]);
    final dx = x(points[i + 1]) - ax;
    final dy = y(points[i + 1]) - ay;
    final squared = dx * dx + dy * dy;
    final length = math.sqrt(squared);
    lengths.add(length);
    final fraction = squared == 0
        ? 0.0
        : ((-ax * dx - ay * dy) / squared).clamp(0.0, 1.0);
    final distance = math.sqrt(
      math.pow(ax + dx * fraction, 2) + math.pow(ay + dy * fraction, 2),
    );
    final along = walked + length * fraction;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestAlong = along;
      bestSegment = i;
      bestFraction = fraction;
    }
    walked += length;
  }

  // Small GPS reversals must not restore an already-traveled trail.
  final forward = math.max(bestAlong, minimumProgressMeters).clamp(0.0, walked);
  if (forward > bestAlong) {
    var cumulative = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      if (cumulative + lengths[i] >= forward) {
        bestSegment = i;
        bestFraction = lengths[i] == 0
            ? 0
            : (forward - cumulative) / lengths[i];
        break;
      }
      cumulative += lengths[i];
    }
  }
  final a = points[bestSegment];
  final b = points[bestSegment + 1];
  final projected = NavigationCoordinate(
    latitude: a.latitude + (b.latitude - a.latitude) * bestFraction,
    longitude: a.longitude + (b.longitude - a.longitude) * bestFraction,
  );
  return RouteProgress(
    remaining: [projected, ...points.skip(bestSegment + 1)],
    traveledMeters: forward,
    remainingMeters: math.max(0, walked - forward),
    offRouteMeters: bestDistance,
  );
}

/// The step whose maneuver is next ahead of [traveledMeters], so guidance
/// names the upcoming turn and walks back to an earlier one on backtracking.
/// Maneuvers are matched in order, so a route that passes the same spot
/// twice still resolves each maneuver to its own pass.
int nextStepIndex(NavigationRoute route, double traveledMeters) {
  final points = route.coordinates;
  final steps = route.steps;
  if (steps.isEmpty) return 0;
  if (points.length < 2) return steps.length - 1;
  const metersPerDegree = 111195.0;
  final lonScale = math.cos(points.first.latitude * math.pi / 180);
  double x(NavigationCoordinate p) =>
      (p.longitude - points.first.longitude) * metersPerDegree * lonScale;
  double y(NavigationCoordinate p) =>
      (p.latitude - points.first.latitude) * metersPerDegree;

  var fromSegment = 0;
  for (var step = 1; step < steps.length; step++) {
    final mx = x(steps[step].maneuver);
    final my = y(steps[step].maneuver);
    var best = double.infinity;
    var along = 0.0;
    var walked = 0.0;
    var bestSegment = fromSegment;
    for (var i = 0; i < points.length - 1; i++) {
      final ax = x(points[i]);
      final ay = y(points[i]);
      final dx = x(points[i + 1]) - ax;
      final dy = y(points[i + 1]) - ay;
      final squared = dx * dx + dy * dy;
      final length = math.sqrt(squared);
      final fraction = squared == 0
          ? 0.0
          : (((mx - ax) * dx + (my - ay) * dy) / squared).clamp(0.0, 1.0);
      final distance =
          math.pow(mx - ax - dx * fraction, 2) +
          math.pow(my - ay - dy * fraction, 2);
      if (i >= fromSegment && distance < best) {
        best = distance.toDouble();
        along = walked + length * fraction;
        bestSegment = i;
      }
      walked += length;
    }
    fromSegment = bestSegment;
    if (along > traveledMeters + 8) return step;
  }
  return steps.length - 1;
}
