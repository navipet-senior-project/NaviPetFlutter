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

void main() {
  group('outdoorRouteWaypoints', () {
    test('keeps an ordered route with first and last point', () {
      final route = [_at(0), _at(20), _at(40), _at(60)];
      expect(outdoorRouteWaypoints(route), route);
    });

    test('drops near-duplicates but keeps both ends', () {
      final route = [_at(0), _at(1), _at(2), _at(30), _at(31)];
      expect(outdoorRouteWaypoints(route), [route[0], route[3], route[4]]);
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
      expect(waypoints.length, lessThanOrEqualTo(outdoorRouteMaxWaypoints));
      expect(waypoints.first, route.first);
      expect(waypoints.last, route.last);
      // Still strictly ordered start to destination.
      for (var i = 1; i < waypoints.length; i++) {
        expect(waypoints[i].latitude, greaterThan(waypoints[i - 1].latitude));
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
