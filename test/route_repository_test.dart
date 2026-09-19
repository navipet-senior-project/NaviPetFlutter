import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/outdoor_route_gateway.dart';
import 'package:navipet/data/route_repository.dart';
import 'package:navipet/data/travel_mode.dart';

const origin = NavigationCoordinate(latitude: 33.7840, longitude: -118.1150);

const destination = NaviDestination(
  name: 'Horn Center',
  address: 'HC',
  coordinate: NavigationCoordinate(
    latitude: 33.78307046,
    longitude: -118.11456126,
  ),
  buildingCode: 'HC',
  type: CampusDestinationType.building,
);

const route = NavigationRoute(
  coordinates: [origin],
  steps: [],
  distanceMeters: 210,
  durationSeconds: 180,
);

class FakeRouteGateway implements OutdoorRouteGateway {
  String? profile;
  Object? error;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    String profile = 'walking',
  }) async {
    this.profile = profile;
    final failure = error;
    if (failure != null) throw failure;
    return route;
  }
}

void main() {
  test('returns a single-route plan for the requested mode', () async {
    final gateway = FakeRouteGateway();
    final repository = RouteRepository(gateway: gateway);

    final plan = await repository.plan(
      origin: origin,
      destination: destination,
      mode: TravelMode.walking,
    );

    expect(plan.routes, [route]);
    expect(plan.selectedIndex, 0);
    expect(plan.mode, TravelMode.walking);
    expect(gateway.profile, 'walking');
  });

  test('marks a room destination as ending at its building', () async {
    final repository = RouteRepository(gateway: FakeRouteGateway());

    final plan = await repository.plan(
      origin: origin,
      destination: const NaviDestination(
        name: 'VEC 404',
        address: 'Vivian Engineering Center',
        coordinate: NavigationCoordinate(
          latitude: 33.7831,
          longitude: -118.1146,
        ),
        type: CampusDestinationType.room,
        buildingCode: 'VEC',
        roomNumber: '404',
      ),
    );

    expect(plan.endsAtBuilding, isTrue);
    expect(
      plan.warnings.single,
      'Walking guidance ends at VEC. Indoor directions are not available yet.',
    );
  });

  test('converts gateway errors into a route failure', () async {
    final gateway = FakeRouteGateway()..error = Exception('boom');
    final repository = RouteRepository(gateway: gateway);

    expect(
      () => repository.plan(origin: origin, destination: destination),
      throwsA(isA<RouteFailure>()),
    );
  });
}
