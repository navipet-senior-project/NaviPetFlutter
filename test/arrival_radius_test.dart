import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';

import 'support/flow_fakes.dart' as harness;

const _metersPerDegreeLatitude = 111195.0;
const _arrivalRadiusMeters = 200 * 0.3048;

/// A point [meters] due north of the destination.
NavigationCoordinate _north(double meters) => NavigationCoordinate(
  latitude: harness.hornCoordinate.latitude + meters / _metersPerDegreeLatitude,
  longitude: harness.hornCoordinate.longitude,
);

NavigationRoute _route({double endpointMeters = 0}) => NavigationRoute(
  coordinates: [_north(endpointMeters + 80), _north(endpointMeters)],
  steps: [
    NavigationStep(
      instruction: 'Walk south',
      distanceMeters: 80,
      durationSeconds: 60,
      maneuver: _north(endpointMeters + 80),
      maneuverType: 'depart',
    ),
  ],
  distanceMeters: 80,
  durationSeconds: 60,
);

CampusPlace _horn({int? radius}) => CampusPlace(
  id: harness.horn.id,
  type: harness.horn.type,
  title: harness.horn.title,
  subtitle: harness.horn.subtitle,
  source: harness.horn.source,
  buildingCode: harness.horn.buildingCode,
  outdoorDestination: harness.hornCoordinate,
  arrivalRadiusMeters: radius,
);

Future<NavigationFlowController> _guide({
  int? radius,
  NavigationRoute? route,
}) async {
  final gateway = harness.FakeRouteGateway()..result = route ?? _route();
  final place = _horn(radius: radius);
  final search = harness.FakeSearchGateway()..results = [place];
  final controller = harness.build(search: search, routes: gateway)
    ..openSearch();
  await controller.selectPlace(place);
  await controller.requestDirections();
  await controller.calculateRoute(continueWithUncertain: true);
  await controller.startRoute(continueWithUncertain: true);
  return controller;
}

Future<void> _fix(
  NavigationFlowController controller,
  double meters, {
  double accuracy = 5,
}) => controller.onLiveLocation(_north(meters), accuracyMeters: accuracy);

void main() {
  for (final radius in [null, 25, 50, 100]) {
    test('missing footprint with radius $radius cannot auto-arrive', () async {
      final controller = await _guide(radius: radius);
      await _fix(controller, 0);
      await _fix(controller, 0);
      expect(controller.state, isA<FlowActiveNavigation>());
    });
  }
  test('route-end offset does not fabricate footprint presence', () async {
    final controller = await _guide(route: _route(endpointMeters: 110));
    await _fix(controller, 110);
    await _fix(controller, 110);
    expect(controller.state, isA<FlowActiveNavigation>());
  });
  test('nearby 200 ft point is not building presence', () async {
    final controller = await _guide();
    expect(
      distanceMeters(harness.hornCoordinate, _north(60)),
      lessThan(_arrivalRadiusMeters),
    );
    await _fix(controller, 60);
    expect(controller.state, isA<FlowActiveNavigation>());
  });
}
