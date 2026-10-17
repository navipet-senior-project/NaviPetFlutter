import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/route_progress.dart';

import 'support/flow_fakes.dart' as harness;

NavigationCoordinate point(double north, [double east = 0]) =>
    NavigationCoordinate(
      latitude: 33.78 + north / 111195,
      longitude: -118.11 + east / 92400,
    );

NavigationRoute route() => NavigationRoute(
  coordinates: [point(0), point(100), point(200), point(300)],
  steps: [
    for (final n in [0.0, 100.0, 200.0, 300.0])
      NavigationStep(
        instruction: 'At $n',
        distanceMeters: 100,
        durationSeconds: 60,
        maneuver: point(n),
      ),
  ],
  distanceMeters: 300,
  durationSeconds: 180,
);

class StreamingLocation extends harness.FakeLocationService {
  final updates = StreamController<NavigationCoordinate>();
  @override
  Stream<NavigationCoordinate> watch() => updates.stream;
}

void main() {
  test(
    'guidance subscribes to GPS and cancels when leaving for overview',
    () async {
      final location = StreamingLocation();
      final gateway = harness.FakeRouteGateway()..result = route();
      final controller = harness.build(location: location, routes: gateway)
        ..openSearch();
      addTearDown(controller.dispose);
      addTearDown(location.updates.close);
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
      expect(location.updates.hasListener, isFalse);
      await controller.startRoute();
      expect(location.updates.hasListener, isTrue);
      location.updates.add(point(150));
      await Future<void>.delayed(Duration.zero);
      expect(
        (controller.state as FlowActiveNavigation)
            .remainingRoute!
            .distanceMeters,
        closeTo(150, 1),
      );
      controller.back();
      expect(controller.state, isA<FlowRoutePreview>());
      expect(location.updates.hasListener, isFalse);
      expect(
        (controller.state as FlowRoutePreview).plan.selected.distanceMeters,
        300,
      );
    },
  );
  test('passed geometry shrinks and returns when the user backtracks', () {
    final original = route();
    final forward = RouteProgress(original, point(150));
    expect(forward.remaining.distanceMeters, closeTo(150, 1));
    expect(forward.remaining.coordinates.length, 3);
    expect(forward.stepIndex, 2);
    final backward = RouteProgress(original, point(50));
    expect(backward.remaining.distanceMeters, closeTo(250, 1));
    expect(backward.remaining.coordinates.length, 4);
    expect(backward.stepIndex, 1);
    expect(original.coordinates.length, 4);
    expect(
      RouteProgress(original, point(50, 60)).distanceFromRoute,
      closeTo(60, 1),
    );
  });

  test('arrival leaves zero distance and degenerate geometry is safe', () {
    expect(
      RouteProgress(route(), point(300)).remaining.distanceMeters,
      closeTo(0, .01),
    );
    final empty = NavigationRoute(
      coordinates: [],
      steps: [],
      distanceMeters: 0,
      durationSeconds: 0,
    );
    expect(RouteProgress(empty, point(0)).remaining, same(empty));
  });

  test(
    'GPS progress preserves guidance; sustained deviation reroutes',
    () async {
      final gateway = harness.FakeRouteGateway()..result = route();
      final controller = harness.build(routes: gateway)..openSearch();
      addTearDown(controller.dispose);
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
      await controller.startRoute();
      await controller.updateNavigationLocation(point(150));
      expect(
        (controller.state as FlowActiveNavigation)
            .remainingRoute!
            .distanceMeters,
        closeTo(150, 1),
      );
      await controller.updateNavigationLocation(point(50));
      expect(
        (controller.state as FlowActiveNavigation)
            .remainingRoute!
            .distanceMeters,
        closeTo(250, 1),
      );
      await controller.updateNavigationLocation(point(50, 60));
      expect(
        gateway.calls,
        1,
      ); // One stray fix does not trigger a network request.
      await controller.updateNavigationLocation(point(50, 65));
      expect(gateway.calls, 2);
      expect(gateway.lastOrigin!.longitude, point(50, 65).longitude);
      expect(controller.state, isA<FlowActiveNavigation>());
      await controller.updateNavigationLocation(point(50, 70));
      expect(gateway.calls, 2); // Retries are throttled.
    },
  );

  test('a reroute cannot reopen guidance after the user ends it', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = harness.build(routes: gateway)..openSearch();
    addTearDown(controller.dispose);
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();
    await controller.updateNavigationLocation(point(50, 60));
    gateway.block();
    final pending = controller.updateNavigationLocation(point(50, 65));
    await Future<void>.delayed(Duration.zero);
    await controller.endRoute();
    gateway.unblock();
    await pending;
    expect(controller.state, isA<FlowIdle>());
  });

  test('reroute failure keeps guidance and the current route', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = harness.build(routes: gateway)..openSearch();
    addTearDown(controller.dispose);
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();
    gateway.error = Exception('offline');
    await controller.updateNavigationLocation(point(50, 60));
    await controller.updateNavigationLocation(point(50, 65));
    expect(controller.state, isA<FlowActiveNavigation>());
    expect(controller.locationNotice, contains('Could not reroute'));
  });
}
