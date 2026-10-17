import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
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

Future<void> fix(
  NavigationFlowController controller,
  NavigationCoordinate coordinate,
) => controller.onLiveLocation(coordinate, accuracyMeters: 5);

Future<NavigationFlowController> startGuidance(
  harness.FakeRouteGateway gateway,
) async {
  final controller = harness.build(routes: gateway)..openSearch();
  await controller.selectPlace(harness.horn);
  await controller.requestDirections();
  await controller.calculateRoute();
  await controller.startRoute();
  return controller;
}

void main() {
  test(
    'only active guidance consumes GPS; overview keeps the chosen route',
    () async {
      final gateway = harness.FakeRouteGateway()..result = route();
      final controller = await startGuidance(gateway);
      addTearDown(controller.dispose);
      await fix(controller, point(150));
      expect(
        (controller.state as FlowActiveNavigation).remainingMeters,
        closeTo(150, 1),
      );
      controller.back();
      expect(controller.state, isA<FlowRoutePreview>());
      await fix(controller, point(250));
      expect(controller.state, isA<FlowRoutePreview>());
      expect(
        (controller.state as FlowRoutePreview).plan.selected.distanceMeters,
        300,
      );
    },
  );

  test('passed geometry shrinks and returns when the user backtracks', () {
    final original = route();
    final forward = projectOntoRoute(original.coordinates, point(150));
    expect(forward.remainingMeters, closeTo(150, 1));
    expect(forward.remaining.length, 3);
    expect(nextStepIndex(original, forward.traveledMeters), 2);
    final backward = projectOntoRoute(original.coordinates, point(50));
    expect(backward.remainingMeters, closeTo(250, 1));
    expect(backward.remaining.length, 4);
    expect(nextStepIndex(original, backward.traveledMeters), 1);
    expect(original.coordinates.length, 4);
    expect(
      projectOntoRoute(original.coordinates, point(50, 60)).offRouteMeters,
      closeTo(60, 1),
    );
  });

  test('arrival leaves zero distance and degenerate geometry is safe', () {
    expect(
      projectOntoRoute(route().coordinates, point(300)).remainingMeters,
      closeTo(0, .01),
    );
    const empty = NavigationRoute(
      coordinates: [],
      steps: [],
      distanceMeters: 0,
      durationSeconds: 0,
    );
    expect(projectOntoRoute(empty.coordinates, point(0)).remaining, isEmpty);
    expect(nextStepIndex(empty, 0), 0);
  });

  test('GPS progress ignores jitter, restores the trail on a real backtrack, '
      'and sustained deviation reroutes', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway);
    addTearDown(controller.dispose);
    FlowActiveNavigation active() => controller.state as FlowActiveNavigation;
    await fix(controller, point(150));
    expect(active().remainingMeters, closeTo(150, 1));
    expect(active().stepIndex, 2);
    await fix(controller, point(140));
    expect(active().remainingMeters, closeTo(150, 1));
    await fix(controller, point(50));
    expect(active().remainingMeters, closeTo(250, 1));
    expect(active().stepIndex, 1);
    await fix(controller, point(50, 60));
    await Future<void>.delayed(Duration.zero);
    // One stray fix does not trigger a network request.
    expect(gateway.calls, 1);
    await fix(controller, point(50, 65));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, 2);
    expect(gateway.lastOrigin!.longitude, point(50, 65).longitude);
    expect(controller.state, isA<FlowActiveNavigation>());
    await fix(controller, point(50, 70));
    await fix(controller, point(50, 75));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, 2); // Retries are throttled.
  });

  test('a reroute cannot reopen guidance after the user ends it', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway);
    addTearDown(controller.dispose);
    await fix(controller, point(50, 60));
    gateway.block();
    await fix(controller, point(50, 65));
    expect(gateway.calls, 2);
    await controller.endRoute();
    gateway.unblock();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<FlowIdle>());
  });

  test('reroute failure keeps guidance and the current route', () async {
    final gateway = harness.FakeRouteGateway()..result = route();
    final controller = await startGuidance(gateway);
    addTearDown(controller.dispose);
    gateway.error = Exception('offline');
    await fix(controller, point(50, 60));
    await fix(controller, point(50, 65));
    await Future<void>.delayed(Duration.zero);
    final active = controller.state as FlowActiveNavigation;
    expect(active.plan.selected.distanceMeters, 300);
    expect(active.routeNotice, contains('Could not update the route'));
  });
}
