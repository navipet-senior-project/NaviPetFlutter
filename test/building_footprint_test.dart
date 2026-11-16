import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/location_service.dart';
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
final _squareRing = [
  _offset(20, -20),
  _offset(20, 20),
  _offset(-20, 20),
  _offset(-20, -20),
  _offset(20, -20),
];

final _square = BuildingFootprint([
  [_squareRing],
]);

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

CampusPlace _horn({BuildingFootprint? footprint, int? radius}) => CampusPlace(
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
  BuildingFootprint? footprint,
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
  await controller.calculateRoute(continueWithUncertain: true);
  await controller.startRoute(continueWithUncertain: true);
  return controller;
}

Future<void> _twice(
  NavigationFlowController controller,
  double north, {
  required double accuracy,
}) async {
  for (var i = 0; i < 2; i++) {
    await controller.onLiveLocation(
      _offset(north),
      accuracyMeters: accuracy,
      timestamp: DateTime.now(),
    );
  }
}

Map<String, Object> _geoJson(BuildingFootprint ring) =>
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
    test('two accurate fixes inside arrive once', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 0, accuracy: 5);
      expect(controller.state, isA<FlowArrived>());
      final arrived = controller.state;
      await _twice(controller, 0, accuracy: 5);
      expect(identical(controller.state, arrived), isTrue);
    });
    test('30 m accuracy cannot confirm building arrival', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 0, accuracy: 30);
      expect(controller.state, isA<FlowActiveNavigation>());
    });
    test('server radius never expands the occupied footprint', () async {
      final controller = await _guide(footprint: _square, radius: 50);
      await _twice(controller, 30, accuracy: 5);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _twice(controller, 0, accuracy: 5);
      expect(controller.state, isA<FlowArrived>());
    });
    test(
      'route end outside footprint never confirms building arrival',
      () async {
        final controller = await _guide(
          footprint: _square,
          route: _routeEnding(50),
        );
        await _twice(controller, 50, accuracy: 5);
        expect(controller.state, isA<FlowActiveNavigation>());
      },
    );
    test('wall and GPS overlap remain uncertain', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 20, accuracy: 5);
      expect(controller.state, isA<FlowActiveNavigation>());
      await _twice(controller, 17, accuracy: 5);
      expect(controller.state, isA<FlowActiveNavigation>());
    });
    test('approach remains guidance, not arrival', () async {
      final controller = await _guide(footprint: _square);
      await _twice(controller, 32, accuracy: 5);
      expect(controller.state, isA<FlowApproaching>());
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
      expect(footprint.polygons.single.single, hasLength(5));
      expect(
        footprint.polygons.single.single.first.latitude,
        _squareRing.first.latitude,
      );
      expect(
        footprint.polygons.single.single.first.longitude,
        _squareRing.first.longitude,
      );
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
      expect(cached.footprint!.polygons.single.single, hasLength(5));
      expect(
        cached.footprint!.polygons.single.single.last.latitude,
        _squareRing.last.latitude,
      );
    });
  });

  group('selecting the building the user is inside', () {
    Future<(NavigationFlowController, harness.RecordingMap)> selectAt(
      NavigationCoordinate position,
    ) async {
      final place = _horn(footprint: _square);
      final search = harness.FakeSearchGateway()..results = [place];
      final map = harness.RecordingMap();
      final location = harness.FakeLocationService()
        ..reading = LocationReading(
          availability: LocationAvailability.available,
          coordinate: position,
        );
      final controller = harness.build(
        search: search,
        location: location,
        map: map,
      )..openSearch();
      await controller.selectPlace(place);
      return (controller, map);
    }

    test(
      'keeps selected building preview inside footprint until Start Route',
      () async {
        final (controller, map) = await selectAt(_offset(0));
        final state = controller.state as FlowPlacePreview;
        expect(state.routable, isTrue);
        expect(map.calls, contains('showPlace:Horn Center'));
      },
    );

    test('shows the normal map destination outside footprint', () async {
      final (controller, map) = await selectAt(_offset(50));
      final state = controller.state as FlowPlacePreview;
      expect(state.routable, isTrue);
      expect(map.calls, contains('showPlace:Horn Center'));
    });
  });
}
