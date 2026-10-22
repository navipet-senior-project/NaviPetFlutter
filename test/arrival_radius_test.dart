import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
<<<<<<< Updated upstream
=======
import 'package:navipet/data/route_progress.dart';
>>>>>>> Stashed changes

import 'support/flow_fakes.dart' as harness;

const _metersPerDegreeLatitude = 111195.0;
<<<<<<< Updated upstream

/// A point [meters] due north of the destination, so it lies on the route.
=======
const _arrivalRadiusMeters = 350 * 0.3048;

/// A point [meters] due north of the destination.
>>>>>>> Stashed changes
NavigationCoordinate _north(double meters) => NavigationCoordinate(
  latitude: harness.hornCoordinate.latitude + meters / _metersPerDegreeLatitude,
  longitude: harness.hornCoordinate.longitude,
);

<<<<<<< Updated upstream
NavigationRoute _route() => NavigationRoute(
  coordinates: [_north(80), harness.hornCoordinate],
=======
NavigationRoute _route({double endpointMeters = 0}) => NavigationRoute(
  coordinates: [_north(endpointMeters + 80), _north(endpointMeters)],
>>>>>>> Stashed changes
  steps: [
    NavigationStep(
      instruction: 'Walk south',
      distanceMeters: 80,
      durationSeconds: 60,
<<<<<<< Updated upstream
      maneuver: _north(80),
=======
      maneuver: _north(endpointMeters + 80),
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
Future<NavigationFlowController> _guide({int? radius}) async {
  final gateway = harness.FakeRouteGateway()..result = _route();
  final search = harness.FakeSearchGateway()..results = [_horn(radius: radius)];
  final controller = harness.build(search: search, routes: gateway)
    ..openSearch();
  await controller.selectPlace(_horn(radius: radius));
=======
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
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
    test('no server value arrives within the 10 m default', () async {
      final controller = await _guide();
      await _fix(controller, 11);
      await _fix(controller, 11);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 9);
      await _fix(controller, 9);
      expect(controller.state, isA<FlowArrived>());
    });

    test('a 25 m radius arrives at 25 m with 15 m accuracy fixes', () async {
      final controller = await _guide(radius: 25);
      await _fix(controller, 26, accuracy: 15);
      await _fix(controller, 26, accuracy: 15);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 24, accuracy: 15);
      await _fix(controller, 24, accuracy: 15);
      expect(controller.state, isA<FlowArrived>());
    });

    test('accuracy limit is capped at 20 m for large radii', () async {
      final controller = await _guide(radius: 50);
      await _fix(controller, 30, accuracy: 25);
      await _fix(controller, 30, accuracy: 25);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 30, accuracy: 20);
      await _fix(controller, 30, accuracy: 20);
      expect(controller.state, isA<FlowArrived>());
    });

    test('accuracy limit never exceeds a small radius', () async {
      final controller = await _guide(radius: 5);
      await _fix(controller, 2, accuracy: 6);
      await _fix(controller, 2, accuracy: 6);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 2, accuracy: 5);
      await _fix(controller, 2, accuracy: 5);
      expect(controller.state, isA<FlowArrived>());
    });

    test('one accurate fix does not arrive; two consecutive do', () async {
      final controller = await _guide();
      await _fix(controller, 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 5);
      expect(controller.state, isA<FlowArrived>());
    });

    test('a miss between accurate fixes resets the count', () async {
      final controller = await _guide();
      await _fix(controller, 5);
      await _fix(controller, 5, accuracy: 40);
      await _fix(controller, 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 20);
      await _fix(controller, 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _fix(controller, 5);
      expect(controller.state, isA<FlowArrived>());
    });

    for (final radius in [2, 51, 100, -5]) {
      test('out-of-range server value $radius falls back to 10 m', () async {
        final controller = await _guide(radius: radius);
        await _fix(controller, 20);
        await _fix(controller, 20);
        expect(controller.state, isNot(isA<FlowArrived>()));
        await _fix(controller, 9);
        await _fix(controller, 9);
        expect(controller.state, isA<FlowArrived>());
      });
    }
  });

  group('approach state', () {
    Future<(NavigationFlowController, List<NavigationFlowState>)> watched({
      int? radius,
    }) async {
      final controller = await _guide(radius: radius);
      final seen = <NavigationFlowState>[];
      controller.addListener(() => seen.add(controller.state));
      return (controller, seen);
    }

    int enters(List<NavigationFlowState> seen) {
      var count = 0;
      for (var i = 0; i < seen.length; i++) {
        final isApproaching = seen[i] is FlowApproaching;
        final wasApproaching = i > 0 && seen[i - 1] is FlowApproaching;
        if (isApproaching && !wasApproaching) count++;
      }
      return count;
    }

    test('fires once at 15 m and stays through later fixes', () async {
      final (controller, seen) = await watched();
      await _fix(controller, 30);
      expect(controller.state, isNot(isA<FlowApproaching>()));
      await _fix(controller, 16);
      expect(controller.state, isNot(isA<FlowApproaching>()));
      await _fix(controller, 14);
      expect(controller.state, isA<FlowApproaching>());
      await _fix(controller, 13);
      await _fix(controller, 30);
      await _fix(controller, 14);
      expect(controller.state, isA<FlowApproaching>());
      expect(enters(seen), 1);
    });

    test('is not emitted by a fix that fails the accuracy gate', () async {
      final (controller, _) = await watched();
      await _fix(controller, 14, accuracy: 40);
      expect(controller.state, isNot(isA<FlowApproaching>()));
      await _fix(controller, 14, accuracy: 11);
      expect(controller.state, isNot(isA<FlowApproaching>()));
    });

    test('arrival still follows the approach state', () async {
      final controller = await _guide();
      await _fix(controller, 14);
      await _fix(controller, 5);
      await _fix(controller, 5);
      expect(controller.state, isA<FlowArrived>());
    });

    test('never fires when the radius is 15 m or more', () async {
      for (final radius in [15, 25, 50]) {
        final (controller, seen) = await watched(radius: radius);
        await _fix(controller, 14);
        expect(
          controller.state,
          isNot(isA<FlowApproaching>()),
          reason: 'radius $radius',
        );
        expect(enters(seen), 0);
      }
    });

    test('fires again on a new trip', () async {
      final controller = await _guide();
      await _fix(controller, 14);
      expect(controller.state, isA<FlowApproaching>());
      await controller.endRoute();
      await controller.selectPlace(_horn());
      await controller.requestDirections();
      await controller.calculateRoute();
      await controller.startRoute();
      expect(controller.state, isNot(isA<FlowApproaching>()));
      await _fix(controller, 14);
      expect(controller.state, isA<FlowApproaching>());
    });
=======
    test(
      'the default 350 ft radius ends guidance on one accurate fix',
      () async {
        final controller = await _guide();

        expect(_arrivalRadiusMeters, closeTo(106.68, 0.01));
        await _fix(controller, 108);
        expect(controller.state, isA<FlowActiveNavigation>());

        await _fix(controller, 106);
        expect(controller.state, isA<FlowArrived>());
      },
    );

    test('a smaller server radius cannot shrink the 350 ft minimum', () async {
      final controller = await _guide(radius: 25);
      await _fix(controller, 108);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _fix(controller, 106);
      expect(controller.state, isA<FlowArrived>());
    });

    test('GPS accuracy must be 20 m or better', () async {
      final controller = await _guide(radius: 50);
      await _fix(controller, 80, accuracy: 21);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _fix(controller, 80, accuracy: 20);
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
>>>>>>> Stashed changes
  });
}
