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
  await controller.calculateRoute();
  await controller.startRoute();
  return controller;
}

Future<void> _fix(
  NavigationFlowController controller,
  double meters, {
  double accuracy = 5,
}) => controller.onLiveLocation(_north(meters), accuracyMeters: accuracy);

void main() {
  group('arrival radius', () {
    test(
      'the default 200 ft radius ends guidance on one accurate fix',
      () async {
        final controller = await _guide();

        expect(_arrivalRadiusMeters, closeTo(60.96, 0.01));
        await _fix(controller, 62);
        expect(controller.state, isA<FlowActiveNavigation>());

        await _fix(controller, 60);
        expect(controller.state, isA<FlowArrived>());
      },
    );

    test('a smaller server radius cannot shrink the 200 ft minimum', () async {
      final controller = await _guide(radius: 25);
      await _fix(controller, 62);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _fix(controller, 60);
      expect(controller.state, isA<FlowArrived>());
    });

    test('GPS accuracy must be 20 m or better', () async {
      final controller = await _guide(radius: 50);
      await _fix(controller, 50, accuracy: 21);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _fix(controller, 50, accuracy: 20);
      expect(controller.state, isA<FlowArrived>());
    });

    test(
      'route remaining distance handles a destination-point offset',
      () async {
        final controller = await _guide(route: _route(endpointMeters: 110));
        expect(
          distanceMeters(harness.hornCoordinate, _north(110)),
          greaterThan(_arrivalRadiusMeters),
        );

        await _fix(controller, 110);
        expect(controller.state, isA<FlowArrived>());
      },
    );

    test('a 100 m server radius is kept', () async {
      final controller = await _guide(radius: 100);
      await _fix(controller, 110);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _fix(controller, 90);
      expect(controller.state, isA<FlowArrived>());
    });

    test(
      'off-route projection cannot trigger arrival past the radius',
      () async {
        final controller = await _guide();
        await controller.onLiveLocation(
          NavigationCoordinate(
            latitude: harness.hornCoordinate.latitude,
            longitude: harness.hornCoordinate.longitude + 0.002,
          ),
          accuracyMeters: 5,
        );
        expect(controller.state, isA<FlowActiveNavigation>());
      },
    );
  });
}
