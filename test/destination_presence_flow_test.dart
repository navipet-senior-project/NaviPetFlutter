import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/destination_presence.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_repository.dart';

import 'support/flow_fakes.dart' as harness;

final outline = validFootprint({
  'type': 'Polygon',
  'coordinates': [
    [
      [-118.115, 33.7827],
      [-118.114, 33.7827],
      [-118.114, 33.7834],
      [-118.115, 33.7834],
      [-118.115, 33.7827],
    ],
  ],
})!;
const outside = NavigationCoordinate(latitude: 33.784, longitude: -118.115);
CampusPlace place({
  bool room = false,
  bool geometry = true,
  NavigationCoordinate? entrance,
}) => CampusPlace(
  id: room ? 'vec119' : harness.horn.id,
  type: room ? CampusDestinationType.room : CampusDestinationType.building,
  title: room ? 'VEC 119' : harness.horn.title,
  subtitle: 'Test',
  source: 'cache',
  outdoorDestination: harness.hornCoordinate,
  footprint: geometry ? outline : null,
  roomNumber: room ? '119' : null,
  indoorDestinationId: room ? 'room119' : null,
  entranceCoordinate: entrance,
);
LocationReading reading(NavigationCoordinate point, {int age = 0}) =>
    LocationReading(
      availability: LocationAvailability.available,
      coordinate: point,
      accuracyMeters: 5,
      timestamp: DateTime.now().subtract(Duration(seconds: age)),
    );
Future<
  (
    NavigationFlowController,
    harness.FakeLocationService,
    harness.FakeRouteGateway,
  )
>
configure({
  bool room = false,
  bool geometry = true,
  NavigationCoordinate point = outside,
}) async {
  final location = harness.FakeLocationService()
    ..reading = reading(point, age: 1);
  final routes = harness.FakeRouteGateway();
  final controller = harness.build(location: location, routes: routes)
    ..openSearch();
  await controller.selectPlace(place(room: room, geometry: geometry));
  await controller.requestDirections();
  return (controller, location, routes);
}

void main() {
  test(
    'Start Route inside enters existing arrived state with zero route requests',
    () async {
      final (controller, location, routes) = await configure(
        point: harness.hornCoordinate,
      );
      expect(controller.state, isA<FlowConfiguringRoute>());
      location.reading = reading(harness.hornCoordinate);
      await controller.calculateRoute();
      expect(controller.state, isA<FlowArrived>());
      expect(controller.status, NavigationStatus.arrived);
      expect(routes.calls, 0);
      expect((controller.state as FlowArrived).summary.distanceMeters, 0);
    },
  );
  test('poor accuracy inside offers AR during active navigation', () async {
    final (controller, location, _) = await configure(room: true);
    location.reading = reading(outside);
    await controller.calculateRoute();
    await controller.startRoute();
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 35,
      timestamp: DateTime.now(),
    );
    expect(controller.state, isA<FlowActiveNavigation>());
    expect(controller.canScanAr, isTrue);
    await controller.onLiveLocation(
      outside,
      accuracyMeters: 35,
      timestamp: DateTime.now(),
    );
    expect(controller.canScanAr, isFalse);
  });
  test('outside follows walking preview and navigation', () async {
    final (controller, location, routes) = await configure();
    location.reading = reading(outside);
    await controller.calculateRoute();
    expect(controller.state, isA<FlowRoutePreview>());
    expect(controller.destinationPresence, DestinationPresence.outside);
    await controller.startRoute();
    expect(controller.status, NavigationStatus.navigating);
    expect(routes.calls, 1);
  });
  test('uncertain never requests route until explicit continue', () async {
    final (controller, location, routes) = await configure();
    location.reading = const LocationReading(
      availability: LocationAvailability.unavailable,
    );
    await controller.calculateRoute();
    expect(controller.awaitingPresenceChoice, isTrue);
    expect(controller.status, NavigationStatus.preview);
    expect(routes.calls, 0);
    await controller.continueRoute();
    expect(controller.state, isA<FlowRoutePreview>());
    await controller.startRoute();
    expect(controller.awaitingPresenceChoice, isTrue);
    await controller.continueRoute();
    expect(controller.state, isA<FlowActiveNavigation>());
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );
    expect(controller.state, isA<FlowActiveNavigation>());
  });
  test(
    'footprintless Start Route skips presence and routes normally',
    () async {
      final (controller, _, routes) = await configure(geometry: false);
      await controller.calculateRoute();
      expect(controller.awaitingPresenceChoice, isFalse);
      expect(controller.state, isA<FlowRoutePreview>());
      await controller.startRoute();
      expect(controller.state, isA<FlowActiveNavigation>());
      expect(routes.calls, 1);
    },
  );
  test(
    'expired preview sample is replaced by a polled fresh reading',
    () async {
      final location = harness.FakeLocationService()
        ..reading = reading(outside, age: 30);
      final controller = harness.build(location: location)..openSearch();
      await controller.selectPlace(place());
      await controller.requestDirections();
      final first = location.queueReading();
      final second = location.queueReading();
      final start = controller.calculateRoute();
      first.complete(reading(outside, age: 1));
      second.complete(reading(outside));
      await start;
      expect(controller.awaitingPresenceChoice, isFalse);
      expect(controller.state, isA<FlowRoutePreview>());
    },
  );
  test(
    'repeated cached timestamp is retried until a fresh fix votes',
    () async {
      final (controller, location, _) = await configure();
      final cached = reading(outside, age: 1);
      location.reading = cached;
      final first = location.queueReading();
      final second = location.queueReading();
      final start = controller.calculateRoute();
      first.complete(cached);
      second.complete(reading(outside));
      await start;
      expect(controller.awaitingPresenceChoice, isFalse);
      expect(controller.state, isA<FlowRoutePreview>());
    },
  );
  test('refresh of uncertain location can confirm direct arrival', () async {
    final (controller, location, routes) = await configure(
      point: harness.hornCoordinate,
    );
    location.reading = const LocationReading(
      availability: LocationAvailability.unavailable,
    );
    await controller.calculateRoute();
    expect(controller.awaitingPresenceChoice, isTrue);
    location.reading = reading(harness.hornCoordinate, age: 1);
    await controller.refreshPresence();
    expect(controller.awaitingPresenceChoice, isTrue);
    location.reading = reading(harness.hornCoordinate);
    await controller.refreshPresence();
    expect(controller.state, isA<FlowArrived>());
    expect(routes.calls, 0);
  });
  test(
    'room inside hands off indoors without final arrival or route request',
    () async {
      final (controller, location, routes) = await configure(
        room: true,
        point: harness.hornCoordinate,
      );
      location.reading = reading(harness.hornCoordinate);
      await controller.calculateRoute();
      expect(controller.state, isA<FlowIndoorHandoff>());
      expect(
        (controller.state as FlowIndoorHandoff).destination.roomNumber,
        '119',
      );
      expect(controller.status, NavigationStatus.navigating);
      expect(routes.calls, 0);
    },
  );
  for (final room in [false, true]) {
    test('live arrival once, room=$room', () async {
      final (controller, location, routes) = await configure(room: room);
      location.reading = reading(outside);
      await controller.calculateRoute();
      await controller.startRoute();
      final terminalStates = <NavigationFlowState>[];
      controller.addListener(() {
        if (controller.state is FlowArrived ||
            controller.state is FlowIndoorHandoff) {
          terminalStates.add(controller.state);
        }
      });
      await controller.onLiveLocation(
        harness.hornCoordinate,
        accuracyMeters: 5,
        timestamp: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(controller.state, isA<FlowActiveNavigation>());
      await controller.onLiveLocation(
        harness.hornCoordinate,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      );
      expect(
        room
            ? controller.state is FlowIndoorHandoff
            : controller.state is FlowArrived,
        isTrue,
      );
      await controller.onLiveLocation(
        harness.hornCoordinate,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      );
      expect(terminalStates, hasLength(1));
      expect(routes.calls, 1);
    });
  }
  test(
    'stale pending Start Route cannot arrive at a replaced destination',
    () async {
      final (controller, location, routes) = await configure(
        point: harness.hornCoordinate,
      );
      final pending = location.queueReading();
      final start = controller.calculateRoute();
      controller.back();
      controller.openSearch();
      await controller.selectPlace(harness.library);
      pending.complete(reading(harness.hornCoordinate));
      await start;
      expect(controller.state, isA<FlowPlacePreview>());
      expect(routes.calls, 0);
    },
  );
  test('continue is nonblocking while a location refresh is pending', () async {
    final (controller, location, routes) = await configure();
    final delayed = location.queueReading();
    final refresh = controller.calculateRoute();
    expect(controller.checkingPresence, isTrue);
    expect(controller.awaitingPresenceChoice, isTrue);
    await controller.continueRoute();
    expect(controller.state, isA<FlowRoutePreview>());
    expect(routes.calls, 1);
    delayed.complete(reading(harness.hornCoordinate));
    await refresh;
    expect(controller.state, isA<FlowRoutePreview>());
  });

  test(
    'routing entrance is distinct from footprint and generic marker fallback',
    () async {
      final routes = harness.FakeRouteGateway();
      final repository = RouteRepository(gateway: routes);
      const entrance = NavigationCoordinate(
        latitude: 33.7827,
        longitude: -118.1145,
      );
      final destination = place(entrance: entrance).toDestination();
      await repository.plan(origin: outside, destination: destination);
      expect(routes.lastDestination, same(entrance));
      expect(destination.coordinate, same(harness.hornCoordinate));
      await repository.plan(
        origin: outside,
        destination: place().toDestination(),
      );
      expect(routes.lastDestination, same(harness.hornCoordinate));
    },
  );
  test('stale live fixes cannot complete a trip', () async {
    final (controller, location, _) = await configure();
    location.reading = reading(outside);
    await controller.calculateRoute();
    await controller.startRoute();
    for (var i = 0; i < 3; i++) {
      await controller.onLiveLocation(
        harness.hornCoordinate,
        accuracyMeters: 5,
        timestamp: DateTime.now().subtract(Duration(seconds: 12 - i)),
      );
    }
    expect(controller.state, isA<FlowActiveNavigation>());
  });
}
