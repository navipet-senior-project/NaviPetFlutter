import 'dart:math' as math;

import 'navigation_models.dart';

/// Projects a GPS fix onto the route without discarding the original geometry.
/// Recomputing from that geometry lets the line grow again when backtracking.
class RouteProgress {
  RouteProgress(NavigationRoute route, NavigationCoordinate coordinate) {
    final points = route.coordinates;
    if (points.length < 2) {
      remaining = route;
      distanceFromRoute = double.infinity;
      stepIndex = 0;
      return;
    }
    final scale = math.cos(coordinate.latitude * math.pi / 180);
    const metersPerDegree = 111195.0;
    (double, double) local(NavigationCoordinate p) => (
      (p.longitude - coordinate.longitude) * scale * metersPerDegree,
      (p.latitude - coordinate.latitude) * metersPerDegree,
    );
    final lengths = <double>[];
    var total = 0.0;
    var nearest = double.infinity;
    var segment = 0;
    var fraction = 0.0;
    var traveled = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final (ax, ay) = local(points[i]);
      final (bx, by) = local(points[i + 1]);
      final dx = bx - ax;
      final dy = by - ay;
      final squared = dx * dx + dy * dy;
      final length = math.sqrt(squared);
      final t = squared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / squared).clamp(0.0, 1.0);
      final distance = math.sqrt(
        math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2),
      );
      if (distance < nearest) {
        nearest = distance;
        segment = i;
        fraction = t;
        traveled = total + t * length;
      }
      lengths.add(length);
      total += length;
    }
    distanceFromRoute = nearest;
    final a = points[segment];
    final b = points[segment + 1];
    final snapped = NavigationCoordinate(
      latitude: a.latitude + (b.latitude - a.latitude) * fraction,
      longitude: a.longitude + (b.longitude - a.longitude) * fraction,
    );
    final ratio = total == 0
        ? 0.0
        : ((total - traveled) / total).clamp(0.0, 1.0);
    remaining = NavigationRoute(
      coordinates: [snapped, ...points.skip(segment + 1)],
      steps: route.steps,
      distanceMeters: route.distanceMeters * ratio,
      durationSeconds: route.durationSeconds * ratio,
    );
    // Maneuvers mark the start of each instruction. Pick the next maneuver
    // ahead of the user, including when they walk back toward an earlier one.
    var nextStep = route.steps.isEmpty ? 0 : route.steps.length - 1;
    var minimumSegment = 0;
    for (var step = 1; step < route.steps.length; step++) {
      final (mx, my) = local(route.steps[step].maneuver);
      var best = double.infinity;
      var along = 0.0;
      var before = 0.0;
      var bestSegment = minimumSegment;
      for (var i = 0; i < lengths.length; i++) {
        final (ax, ay) = local(points[i]);
        final (bx, by) = local(points[i + 1]);
        final dx = bx - ax;
        final dy = by - ay;
        final squared = dx * dx + dy * dy;
        final t = squared == 0
            ? 0.0
            : (((mx - ax) * dx + (my - ay) * dy) / squared).clamp(0.0, 1.0);
        final distance =
            math.pow(mx - ax - t * dx, 2) + math.pow(my - ay - t * dy, 2);
        if (i >= minimumSegment && distance < best) {
          best = distance.toDouble();
          along = before + t * lengths[i];
          bestSegment = i;
        }
        before += lengths[i];
      }
      minimumSegment = bestSegment;
      if (along > traveled + 8) {
        nextStep = step;
        break;
      }
    }
    stepIndex = nextStep;
  }

  late final NavigationRoute remaining;
  late final double distanceFromRoute;
  late final int stepIndex;
}
