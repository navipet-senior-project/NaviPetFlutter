import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';
import 'package:navipet/data/travel_mode.dart';

import 'support/flow_fakes.dart' as harness;

const start = NavigationCoordinate(latitude: 33.7840, longitude: -118.1150);
const middle = NavigationCoordinate(latitude: 33.7835, longitude: -118.1148);
const end = harness.hornCoordinate;
const detour = NavigationCoordinate(latitude: 33.7850, longitude: -118.1160);

NavigationRoute route() => const NavigationRoute(
  coordinates: [start, middle, end],
  steps: [
    NavigationStep(
      instruction: 'Start walking',
      distanceMeters: 60,
      durationSeconds: 50,
      maneuver: start,
      maneuverType: 'depart',
    ),
    NavigationStep(
      instruction: 'Continue to Horn Center',
      distanceMeters: 60,
      durationSeconds: 50,
      maneuver: middle,
      maneuverType: 'continue',
    ),
  ],
  distanceMeters: 120,
  durationSeconds: 100,
);

Future<NavigationFlowController> startGuidance({
  harness.FakeRouteGateway? gateway,
  harness.RecordingMap? map,
}) async {
  final controller = harness.build(routes: gateway, map: map)..openSearch();
  await controller.selectPlace(harness.horn);
  await controller.requestDirections();
  await controller.calculateRoute();
  await controller.startRoute();
  return controller;
}

void main() {
  test('route projection removes traveled geometry and never restores it', () {
    final halfway = projectOntoRoute(route().coordinates, middle);
    expect(
      halfway.remaining.first.latitude,
      closeTo(middle.latitude, 0.000001),
    );
    expect(halfway.remainingMeters, lessThan(120));
    final reversed = projectOntoRoute(
      route().coordinates,
      start,
      minimumProgressMeters: halfway.traveledMeters,
    );
    expect(reversed.traveledMeters, halfway.traveledMeters);
    expect(
      reversed.remaining.first.latitude,
      closeTo(middle.latitude, 0.000001),
    );
  });

  test(
    'live movement advances instructions and redraws remaining route',
    () async {
      final gateway = harness.FakeRouteGateway()..result = route();
      final map = harness.RecordingMap();
      final controller = await startGuidance(gateway: gateway, map: map);
      await controller.onLiveLocation(start, accuracyMeters: 5);
      await controller.onLiveLocation(middle, accuracyMeters: 5);
      final active = controller.state as FlowActiveNavigation;
      expect(active.position, middle);
      expect(active.stepIndex, 1);
      expect(
        active.remainingGeometry.first.latitude,
        closeTo(middle.latitude, 0.000001),
      );
      expect(active.remainingMeters, lessThan(route().distanceMeters));
      expect(active.distanceTraveledMeters, greaterThan(0));
      expect(
        map.calls.where((call) => call.startsWith('showGuidance')).length,
        3,
      );
      expect(map.guidancePositions.last, middle);
      expect(
        map.guidanceRoutes.last.first.latitude,
        closeTo(middle.latitude, 0.000001),
      );
    },
  );

  test('two off-route fixes reroute from the live position', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway: gateway);
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    expect(gateway.calls, 1);
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, 2);
    expect(gateway.lastOrigin, detour);
    expect(
      (controller.state as FlowActiveNavigation).plan.mode,
      TravelMode.walking,
    );
  });

  test('failed reroute keeps guidance and waits before retrying', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway: gateway);
    gateway.error = StateError('offline');
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    await Future<void>.delayed(Duration.zero);
    expect(
      (controller.state as FlowActiveNavigation).routeNotice,
      contains('Retrying'),
    );
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    expect(gateway.calls, 2);
  });

  test('arrival needs two accurate fixes and shows trip summary', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final map = harness.RecordingMap();
    final controller = await startGuidance(gateway: gateway, map: map);
    await controller.onLiveLocation(middle, accuracyMeters: 5);
    await controller.onLiveLocation(end, accuracyMeters: 40);
    expect(controller.state, isA<FlowActiveNavigation>());
    await controller.onLiveLocation(end, accuracyMeters: 5);
    expect(controller.state, isA<FlowActiveNavigation>());
    await controller.onLiveLocation(end, accuracyMeters: 5);
    final arrived = controller.state as FlowArrived;
    expect(arrived.destination.name, 'Horn Center');
    expect(arrived.summary.distanceMeters, greaterThan(0));
    expect(map.calls.last, 'clear');
    await controller.dismissArrival();
    expect(controller.state, isA<FlowIdle>());
  });

  test(
    'the default 10 meter radius ends navigation after two accurate fixes',
    () async {
      final gateway = harness.FakeRouteGateway()..result = route();
      final controller = await startGuidance(gateway: gateway);
      final outsideRadius = NavigationCoordinate(
        latitude: end.latitude + 0.00011,
        longitude: end.longitude,
      );
      final insideRadius = NavigationCoordinate(
        latitude: end.latitude + 0.00008,
        longitude: end.longitude,
      );

      expect(distanceMeters(end, outsideRadius), greaterThan(10));
      expect(distanceMeters(end, insideRadius), lessThan(10));

      await controller.onLiveLocation(outsideRadius, accuracyMeters: 5);
      await controller.onLiveLocation(outsideRadius, accuracyMeters: 5);
      expect(controller.state, isA<FlowActiveNavigation>());

      await controller.onLiveLocation(insideRadius, accuracyMeters: 5);
      expect(controller.state, isA<FlowActiveNavigation>());
      await controller.onLiveLocation(insideRadius, accuracyMeters: 5);
      expect(controller.state, isA<FlowArrived>());
    },
  );

  test('late reroute cannot restore a manually ended trip', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway: gateway);
    gateway.block();
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    await controller.onLiveLocation(detour, accuracyMeters: 5);
    expect(gateway.calls, 2);
    await controller.endRoute();
    gateway.unblock();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<FlowIdle>());
  });
}
