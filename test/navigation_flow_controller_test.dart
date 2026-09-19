import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/travel_mode.dart';

import 'support/flow_fakes.dart' as harness;

void main() {
  test('starts idle', () {
    expect(harness.build().state, isA<FlowIdle>());
  });

  test('opening search enters the searching state', () {
    final controller = harness.build()..openSearch();

    expect(controller.state, isA<FlowSearching>());
  });

  test('selecting a mapped place opens a routable preview', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();

    await controller.selectPlace(harness.horn);

    final state = controller.state as FlowPlacePreview;
    expect(state.routable, isTrue);
    expect(state.destination!.name, 'Horn Center');
    expect(map.calls, contains('showPlace:Horn Center'));
  });

  test('selecting an unmapped place opens a non-routable preview', () async {
    final controller = harness.build()..openSearch();

    await controller.selectPlace(harness.unmapped);

    final state = controller.state as FlowPlacePreview;
    expect(state.routable, isFalse);
    expect(state.destination, isNull);
  });

  test('selecting a place records it in recents', () async {
    final recents = harness.FakeRecents();
    final controller = harness.build(recents: recents)..openSearch();

    await controller.selectPlace(harness.horn);

    expect(recents.saved, [harness.horn.id]);
  });

  test('back from a preview returns to search with the query kept', () async {
    final controller = harness.build()..openSearch();
    controller.queryChanged('horn');
    await controller.selectPlace(harness.horn);

    controller.back();

    final state = controller.state as FlowSearching;
    expect(state.query, 'horn');
  });

  test('back from search returns to idle and clears the map', () {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();

    controller.back();

    expect(controller.state, isA<FlowIdle>());
    expect(map.calls, contains('clear'));
  });

  test(
    'a stale selectPlace reply is discarded once a newer one lands',
    () async {
      final search = harness.FakeSearchGateway();
      // Block the first selectPlace's gateway reply so it stays in flight
      // while a second, newer selectPlace runs to completion first.
      search.blockPlace(harness.horn.id);
      final controller = harness.build(search: search)..openSearch();

      final firstSelect = controller.selectPlace(harness.horn);
      await controller.selectPlace(harness.unmapped);

      // Now let the stale first reply land.
      search.unblockPlace(harness.horn.id);
      await firstSelect;

      final state = controller.state as FlowPlacePreview;
      expect(state.place.id, harness.unmapped.id);
      expect(state.routable, isFalse);
    },
  );

  test('directions defaults the origin to the live location', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);

    await controller.requestDirections();

    final state = controller.state as FlowConfiguringRoute;
    expect(state.origin, isA<CurrentLocationOrigin>());
    expect(state.origin.canStartGuidance, isTrue);
    expect(state.mode, TravelMode.walking);
  });

  test('directions asks for a starting point without permission', () async {
    final location = harness.FakeLocationService()
      ..reading = const LocationReading(
        availability: LocationAvailability.permissionDenied,
      );
    final controller = harness.build(location: location)..openSearch();
    await controller.selectPlace(harness.horn);

    await controller.requestDirections();

    final state = controller.state as FlowConfiguringRoute;
    expect(state.origin, isA<UnknownOrigin>());
    expect(state.origin.canStartGuidance, isFalse);
  });

  test('calculating a route reaches the preview and draws it', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    await controller.calculateRoute();

    final state = controller.state as FlowRoutePreview;
    expect(state.plan.selected.durationSeconds, 180);
    expect(map.calls, contains('showRoute:Horn Center'));
  });

  test('a routing failure becomes a retryable error', () async {
    final routes = harness.FakeRouteGateway()..error = Exception('offline');
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    await controller.calculateRoute();

    final state = controller.state as FlowError;
    expect(state.retryable, isTrue);
    expect(state.previous, isA<FlowConfiguringRoute>());
  });

  test('retry re-runs the calculation', () async {
    final routes = harness.FakeRouteGateway()..error = Exception('offline');
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    routes.error = null;
    await controller.retry();

    expect(controller.state, isA<FlowRoutePreview>());
    expect(routes.calls, 2);
  });

  test('changing mode recalculates', () async {
    final routes = harness.FakeRouteGateway();
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    await controller.setMode(TravelMode.walking);

    expect(routes.calls, 2);
    expect(controller.state, isA<FlowRoutePreview>());
  });

  test('steps open and close without losing the plan', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    final plan = (controller.state as FlowRoutePreview).plan;

    controller.showSteps();
    expect(controller.state, isA<FlowRouteSteps>());
    expect((controller.state as FlowRouteSteps).plan, plan);

    controller.hideSteps();
    expect(controller.state, isA<FlowRoutePreview>());
  });

  test('guidance starts only from the live location', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    await controller.startRoute();
    expect(controller.state, isA<FlowActiveNavigation>());

    await controller.endRoute();
    expect(controller.state, isA<FlowRoutePreview>());
  });

  test('guidance is refused for a manually chosen origin', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    controller.setOrigin(
      const PlaceOrigin(
        place: NaviDestination(
          name: 'Library',
          address: 'LIB',
          coordinate: NavigationCoordinate(
            latitude: 33.7789,
            longitude: -118.1140,
          ),
        ),
      ),
    );
    await controller.calculateRoute();

    await controller.startRoute();

    expect(controller.state, isA<FlowRoutePreview>());
  });

  test(
    'a stale route reply is discarded after the destination changes',
    () async {
      final controller = harness.build()..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      final pending = controller.calculateRoute();
      await controller.selectPlace(harness.unmapped);
      await pending;

      expect(controller.state, isA<FlowPlacePreview>());
    },
  );

  test('the indoor handoff state is never entered', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();

    expect(controller.state, isNot(isA<FlowIndoorHandoff>()));
  });

  // The three tests below force the ordering the tests above leave to
  // chance: each blocks the in-flight async reply so a newer flow action
  // provably completes first, then releases it. Without the matching
  // `generation != _generation` guard, releasing the block would let the
  // stale reply overwrite the newer state and the final `expect` would see
  // the stale state instead.

  test('a stale location reply is discarded once a newer destination is '
      'selected', () async {
    final location = harness.FakeLocationService()..block();
    final controller = harness.build(location: location)..openSearch();
    await controller.selectPlace(harness.horn);

    final pending = controller.requestDirections();
    await controller.selectPlace(harness.unmapped);
    location.unblock();
    await pending;

    expect(controller.state, isA<FlowPlacePreview>());
  });

  test('a stale successful route reply is discarded once a newer destination '
      'is selected', () async {
    final routes = harness.FakeRouteGateway()..block();
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    final pending = controller.calculateRoute();
    await controller.selectPlace(harness.unmapped);
    routes.unblock();
    await pending;

    expect(controller.state, isA<FlowPlacePreview>());
  });

  test('a stale route failure is discarded once a newer destination is '
      'selected', () async {
    final routes = harness.FakeRouteGateway()
      ..block()
      ..error = Exception('offline');
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    final pending = controller.calculateRoute();
    await controller.selectPlace(harness.unmapped);
    routes.unblock();
    await pending;

    expect(controller.state, isA<FlowPlacePreview>());
  });
}
