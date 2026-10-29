import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';
import 'package:navipet/data/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow_fakes.dart' as harness;

const _metersPerDegreeLatitude = 111195.0;

/// A point [north] / [east] meters from the destination.
NavigationCoordinate _offset(double north, [double east = 0]) =>
    NavigationCoordinate(
      latitude:
          harness.hornCoordinate.latitude + north / _metersPerDegreeLatitude,
      longitude:
          harness.hornCoordinate.longitude +
          east / (_metersPerDegreeLatitude * 0.8313),
    );

/// A 40 m square centered on the destination: walls 20 m from the center.
final _square = [
  _offset(20, -20),
  _offset(20, 20),
  _offset(-20, 20),
  _offset(-20, -20),
  _offset(20, -20),
];

NavigationRoute _route() => NavigationRoute(
  coordinates: [_offset(80), harness.hornCoordinate],
  steps: [
    NavigationStep(
      instruction: 'Walk south',
      distanceMeters: 80,
      durationSeconds: 60,
      maneuver: _offset(80),
      maneuverType: 'depart',
    ),
  ],
  distanceMeters: 80,
  durationSeconds: 60,
);

CampusPlace _horn({List<NavigationCoordinate>? footprint, int? radius}) =>
    CampusPlace(
      id: harness.horn.id,
      type: harness.horn.type,
      title: harness.horn.title,
      subtitle: harness.horn.subtitle,
      source: harness.horn.source,
      buildingCode: harness.horn.buildingCode,
      outdoorDestination: harness.hornCoordinate,
      arrivalRadiusMeters: radius,
      footprint: footprint,
    );

NavigationRoute _routeEnding(double north) => NavigationRoute(
  coordinates: [_offset(north + 80), _offset(north)],
  steps: [
    NavigationStep(
      instruction: 'Walk south',
      distanceMeters: 80,
      durationSeconds: 60,
      maneuver: _offset(north + 80),
      maneuverType: 'depart',
    ),
  ],
  distanceMeters: 80,
  durationSeconds: 60,
);

Future<NavigationFlowController> _guide({
  List<NavigationCoordinate>? footprint,
  int? radius,
  NavigationRoute? route,
}) async {
  final place = _horn(footprint: footprint, radius: radius);
  final gateway = harness.FakeRouteGateway()..result = route ?? _route();
  final search = harness.FakeSearchGateway()..results = [place];
  final controller = harness.build(search: search, routes: gateway)
    ..openSearch();
  await controller.selectPlace(place);
  await controller.requestDirections();
  await controller.calculateRoute();
  await controller.startRoute();
  return controller;
}

Future<void> _twice(
  NavigationFlowController controller,
  double north, {
  required double accuracy,
}) async {
  for (var i = 0; i < 2; i++) {
    await controller.onLiveLocation(_offset(north), accuracyMeters: accuracy);
  }
}

Map<String, Object> _geoJson(List<NavigationCoordinate> ring) =>
    footprintToGeoJson(ring);

void main() {
  group('distanceToFootprintMeters', () {
    test('is zero inside and the wall distance outside', () {
      expect(distanceToFootprintMeters(_square, _offset(0)), 0);
      expect(distanceToFootprintMeters(_square, _offset(19, 19)), 0);
      expect(distanceToFootprintMeters(_square, _offset(30)), closeTo(10, 0.5));
    });
  });

  group('arrival at a building footprint', () {
    test('a 30 m accuracy fix inside the building arrives', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 5, accuracy: 30);
      expect(controller.state, isA<FlowArrived>());
    });

    test('a 30 m fix does not arrive at a point destination', () async {
      final controller = await _guide();
      await _twice(controller, 5, accuracy: 30);
      expect(controller.state, isNot(isA<FlowArrived>()));
    });

    test('a fix 15 to 60 m from the wall does not arrive', () async {
      final controller = await _guide(footprint: _square);
      final gap = distanceToFootprintMeters(_square, _offset(50));
      expect(gap, greaterThanOrEqualTo(15));
      expect(gap, lessThanOrEqualTo(60));
      await _twice(controller, 50, accuracy: 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
    });

    test('the route end does not arrive a footprint past the wall', () async {
      const north = 50.0;
      final controller = await _guide(
        footprint: _square,
        route: _routeEnding(north),
      );
      expect(
        distanceToFootprintMeters(_square, _offset(north)),
        greaterThan(10),
      );
      await _twice(controller, north, accuracy: 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
    });

    test('server radii 25 and 50 are measured from the wall', () async {
      final narrow = await _guide(footprint: _square, radius: 25);
      expect(distanceToFootprintMeters(_square, _offset(50)), greaterThan(25));
      await _twice(narrow, 50, accuracy: 5);
      expect(narrow.state, isNot(isA<FlowArrived>()));
      expect(distanceToFootprintMeters(_square, _offset(40)), lessThan(25));
      await _twice(narrow, 40, accuracy: 5);
      expect(narrow.state, isA<FlowArrived>());

      final wide = await _guide(footprint: _square, radius: 50);
      expect(distanceToFootprintMeters(_square, _offset(80)), greaterThan(50));
      await _twice(wide, 80, accuracy: 5);
      expect(wide.state, isNot(isA<FlowArrived>()));
      expect(distanceToFootprintMeters(_square, _offset(60)), lessThan(50));
      await _twice(wide, 60, accuracy: 5);
      expect(wide.state, isA<FlowArrived>());
    });

    test('35 m needs two fixes and a 36 m jitter resets them', () async {
      final controller = await _guide(footprint: _square);
      await controller.onLiveLocation(_offset(0), accuracyMeters: 35);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await controller.onLiveLocation(_offset(0), accuracyMeters: 36);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await controller.onLiveLocation(_offset(0), accuracyMeters: 35);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await controller.onLiveLocation(_offset(0), accuracyMeters: 35);
      expect(controller.state, isA<FlowArrived>());
    });

    test('announces approach between the wall radius and 15 m', () async {
      final controller = await _guide(footprint: _square);
      await controller.onLiveLocation(_offset(32), accuracyMeters: 5);
      expect(controller.state, isA<FlowApproaching>());
    });

    test('the 10 m radius is measured from the wall', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 35, accuracy: 5);
      expect(controller.state, isNot(isA<FlowArrived>()));
      await _twice(controller, 28, accuracy: 5);
      expect(controller.state, isA<FlowArrived>());
    });

    test('fixes worse than 35 m never arrive', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 0, accuracy: 36);
      expect(controller.state, isNot(isA<FlowArrived>()));
    });
  });

  group('footprint parsing', () {
    Map<String, dynamic> json(Object? footprint) => {
      'id': '00000000-0000-4000-8000-000000000004',
      'type': 'building',
      'title': 'Horn Center',
      'subtitle': 'HC',
      'source': 'csulb',
      'navigation': {
        'outdoorDestination': {'latitude': 33.7831, 'longitude': -118.1146},
        'footprint': footprint,
      },
    };

    test('reads the outer ring into the destination', () {
      final place = CampusPlace.fromJson(json(_geoJson(_square)));
      final footprint = place.toDestination().footprint!;
      expect(footprint, hasLength(5));
      expect(footprint.first.latitude, _square.first.latitude);
      expect(footprint.first.longitude, _square.first.longitude);
    });

    test('drops malformed footprints', () {
      final ring = _geoJson(_square)['coordinates']! as List;
      final positions = ring.first as List;
      for (final bad in [
        null,
        'Polygon',
        {'type': 'Point', 'coordinates': ring},
        {
          'type': 'Polygon',
          'coordinates': [positions.sublist(1)],
        },
        {
          'type': 'Polygon',
          'coordinates': [
            [...positions.sublist(0, 4), positions[1]],
          ],
        },
        {
          'type': 'Polygon',
          'coordinates': [
            [
              ['a', 1],
              ...positions.sublist(1),
            ],
          ],
        },
      ]) {
        expect(
          CampusPlace.fromJson(json(bad)).footprint,
          isNull,
          reason: '$bad',
        );
      }
    });

    test('survives the recents cache', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SearchHistoryStore();
      await store.add(_horn(footprint: _square).toDestination());
      final [cached] = await store.load();
      expect(cached.footprint, hasLength(5));
      expect(cached.footprint!.last.latitude, _square.last.latitude);
    });
  });
}
