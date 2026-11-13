import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/outdoor_ar_contract.dart';

const _destination = NaviDestination(
  name: 'Library',
  address: '',
  coordinate: NavigationCoordinate(latitude: 33.78, longitude: -118.11),
);

NavigationCoordinate _at(double northMeters) => NavigationCoordinate(
  latitude: 33.78 + northMeters / 111195,
  longitude: -118.11,
);

NavigationCoordinate _atMeters(double north, double east) =>
    NavigationCoordinate(
      latitude: 33.78 + north / 111195,
      longitude: -118.11 + east / (111195 * math.cos(33.78 * math.pi / 180)),
    );

void main() {
  group('outdoorRouteWaypoints', () {
    test('thins a straight route while keeping its endpoints', () {
      final route = [_at(0), _at(20), _at(40), _at(60)];
      expect(outdoorRouteWaypoints(route), [route.first, route.last]);
    });

    test('preserves a corner whose shortcut exceeds the tolerance', () {
      final route = [
        _atMeters(0, 0),
        _atMeters(3, 0),
        _atMeters(3, 3),
        _atMeters(0, 6),
      ];
      final waypoints = outdoorRouteWaypoints(route)!;
      expect(waypoints.first, route.first);
      expect(waypoints.last, route.last);
      expect(waypoints, contains(route[1]));
    });

    test('preserves gradual bends beyond the perpendicular tolerance', () {
      final route = [
        for (var i = 0; i <= 200; i++)
          _atMeters(8 * math.sin(i * math.pi / 50), i.toDouble()),
      ];
      final waypoints = outdoorRouteWaypoints(route)!;
      expect(waypoints.length, greaterThan(2));
      expect(waypoints.first, route.first);
      expect(waypoints.last, route.last);
      expect(
        waypoints.any((point) => point.latitude > _atMeters(6, 0).latitude),
        isTrue,
      );
    });

    test('is absent without a route Unity can follow', () {
      expect(outdoorRouteWaypoints(const []), isNull);
      expect(outdoorRouteWaypoints([_at(0)]), isNull);
    });

    test('is absent when any point is not a real coordinate', () {
      for (final bad in [
        const NavigationCoordinate(latitude: double.nan, longitude: 0),
        const NavigationCoordinate(latitude: 0, longitude: double.infinity),
        const NavigationCoordinate(latitude: 91, longitude: 0),
        const NavigationCoordinate(latitude: 0, longitude: -181),
      ]) {
        expect(outdoorRouteWaypoints([_at(0), bad, _at(50)]), isNull);
      }
    });

    test('fits a very long route without cutting it short', () {
      final route = [for (var i = 0; i <= 4000; i++) _at(i * 6.0)];
      final waypoints = outdoorRouteWaypoints(route)!;
      expect(waypoints, [route.first, route.last]);
      expect(waypoints.first, route.first);
      expect(waypoints.last, route.last);
    });

    test('widens tolerance to fit the waypoint cap without truncating', () {
      final route = [
        for (var i = 0; i <= 4000; i++)
          _atMeters(i.isEven ? 0 : 5, i.toDouble()),
      ];
      final waypoints = outdoorRouteWaypoints(route)!;
      expect(waypoints.length, lessThanOrEqualTo(outdoorRouteMaxWaypoints));
      expect(waypoints.first, route.first);
      expect(waypoints.last, route.last);
      for (var i = 1; i < waypoints.length; i++) {
        expect(waypoints[i].longitude, greaterThan(waypoints[i - 1].longitude));
      }
    });
  });

  group('OutdoorArRequest', () {
    test('adds route.waypoints from the walking route', () {
      final json = OutdoorArRequest.to(
        _destination,
        route: [_at(0), _at(50)],
      ).toJson();
      expect(json['route'], {
        'waypoints': [
          {'latitude': _at(0).latitude, 'longitude': _at(0).longitude},
          {'latitude': _at(50).latitude, 'longitude': _at(50).longitude},
        ],
      });
      expect(json['schemaVersion'], 2);
      expect(json['dataUseAccepted'], true);
    });

    test('omits route when there is none so Unity says direction only', () {
      expect(
        OutdoorArRequest.to(_destination).toJson(),
        isNot(contains('route')),
      );
      expect(
        OutdoorArRequest.to(_destination, route: [_at(0)]).toJson(),
        isNot(contains('route')),
      );
    });
  });
}
