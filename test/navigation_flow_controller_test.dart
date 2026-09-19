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

  test('back from search returns to idle and clears the map', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();

    controller.back();
    // back() queues the map clear rather than firing it directly (see
    // NavigationFlowController._queueMap), so it lands a microtask later
    // rather than synchronously within back() itself.
    await Future<void>.delayed(Duration.zero);

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

  // Fix-round additions (review findings on the first pass):
  // closing the origin-picking loop, redrawing the map on back() out of a
  // route, delegating back()'s FlowRouteSteps/FlowActiveNavigation arms to
  // hideSteps()/endRoute(), and rejecting a disabled travel mode.

  test('picking an origin restores the destination and mode', () async {
    final search = harness.FakeSearchGateway()
      ..results = const [harness.horn, harness.library];
    final controller = harness.build(search: search)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    final before = controller.state as FlowConfiguringRoute;

    controller.openSearch(pickingOrigin: true);
    final searching = controller.state as FlowSearching;
    expect(searching.pickingOrigin, isTrue);
    expect(searching.configuringRoute, isNotNull);

    await controller.selectPlace(harness.library);

    final after = controller.state as FlowConfiguringRoute;
    expect(after.destination.name, before.destination.name);
    expect(after.mode, before.mode);
    expect(after.origin, isA<PlaceOrigin>());
    expect((after.origin as PlaceOrigin).place.name, 'University Library');
  });

  test('an ordinary search does not carry a route to restore', () async {
    final controller = harness.build()..openSearch();

    final state = controller.state as FlowSearching;
    expect(state.pickingOrigin, isFalse);
    expect(state.configuringRoute, isNull);

    await controller.selectPlace(harness.horn);
    expect(controller.state, isA<FlowPlacePreview>());
  });

  test(
    'picking an origin with an unmapped place stays in picking mode',
    () async {
      final controller = harness.build()..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();

      controller.openSearch(pickingOrigin: true);
      await controller.selectPlace(harness.unmapped);

      final state = controller.state as FlowSearching;
      expect(state.pickingOrigin, isTrue);
      expect(state.configuringRoute, isNotNull);
    },
  );

  test('back from a route preview redraws the place instead of leaving the '
      'route on the map', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    map.calls.clear();

    controller.back();
    // Queued behind _mapWork rather than fired directly (see the map-work
    // serialization fix), so it lands a microtask later rather than
    // synchronously within back() itself.
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, isA<FlowPlacePreview>());
    expect(map.calls, contains('showPlace:Horn Center'));
  });

  test('back from route steps behaves like closing the steps sheet', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    final plan = (controller.state as FlowRoutePreview).plan;
    controller.showSteps();

    controller.back();

    expect(controller.state, isA<FlowRoutePreview>());
    expect((controller.state as FlowRoutePreview).plan, plan);
  });

  test('back from active navigation behaves like ending the route', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();

    controller.back();

    expect(controller.state, isA<FlowRoutePreview>());
  });

  test('setMode ignores a travel mode that is not enabled', () async {
    final routes = harness.FakeRouteGateway();
    final controller = harness.build(routes: routes)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    await controller.setMode(TravelMode.accessible);

    expect(routes.calls, 1);
    expect((controller.state as FlowRoutePreview).mode, TravelMode.walking);
  });

  // Fix-round 2 additions: round 1 closed the forward path into the origin
  // picker but left three ways back out of it (or back into it) broken.

  test('re-entering the origin picker does not lose the route being '
      'configured', () async {
    final search = harness.FakeSearchGateway()
      ..results = const [harness.horn, harness.library];
    final controller = harness.build(search: search)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    final before = controller.state as FlowConfiguringRoute;

    controller.openSearch(pickingOrigin: true);
    // Reopening the picker while already picking (e.g. the search screen
    // being reopened) must carry the snapshot forward rather than
    // recapturing from `_state`, which by now is `FlowSearching`, not
    // the `FlowConfiguringRoute` being interrupted.
    controller.openSearch(pickingOrigin: true);

    final searching = controller.state as FlowSearching;
    expect(searching.pickingOrigin, isTrue);
    expect(searching.configuringRoute, isNotNull);

    await controller.selectPlace(harness.library);

    final after = controller.state as FlowConfiguringRoute;
    expect(after.destination.name, before.destination.name);
    expect(after.mode, before.mode);
    expect(after.origin, isA<PlaceOrigin>());
  });

  test('requesting the origin picker with nothing to configure opens an '
      'ordinary search', () {
    final controller = harness.build();

    controller.openSearch(pickingOrigin: true);

    // There is no FlowConfiguringRoute to interrupt, so the incoherent
    // combination of "picking" with nothing to return to must not be
    // representable: pickingOrigin is derived from configuringRoute, so
    // it comes back false here rather than a dangling true.
    final state = controller.state as FlowSearching;
    expect(state.pickingOrigin, isFalse);
    expect(state.configuringRoute, isNull);
  });

  test(
    'back out of the origin picker restores the route being configured',
    () async {
      final map = harness.RecordingMap();
      final controller = harness.build(map: map)..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      final before = controller.state as FlowConfiguringRoute;

      controller.openSearch(pickingOrigin: true);
      map.calls.clear();

      controller.back();

      final after = controller.state as FlowConfiguringRoute;
      expect(after.destination.name, before.destination.name);
      expect(after.mode, before.mode);
      expect(after.origin, isA<CurrentLocationOrigin>());
      // Backing out of the picker is not abandoning the flow: it must not
      // be treated like back() from an ordinary search.
      await Future<void>.delayed(Duration.zero);
      expect(map.calls, isNot(contains('clear')));
    },
  );

  test('picking an origin with an unmapped place surfaces why nothing '
      'happened', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    controller.openSearch(pickingOrigin: true);
    await controller.selectPlace(harness.unmapped);

    final state = controller.state as FlowSearching;
    expect(state.pickingOrigin, isTrue);
    expect(state.configuringRoute, isNotNull);
    expect(state.pickError, isNotNull);
  });

  test('map work from back() and a fresh route calculation stays in request '
      'order', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    map.calls.clear();
    map.blockShowPlace();
    // back() queues showPlace(Horn Center) for the place sheet, blocked.
    controller.back();

    // Re-requesting directions and recalculating immediately — before
    // the blocked showPlace resolves — is the exact interleaving the
    // review found: without a serialized map queue, showRoute's fake
    // (never blocked) could finish and record itself before the stale
    // showPlace call catches up, which is indistinguishable here from
    // the real bug where a slow-but-earlier map call overwrites a
    // fast-but-later one.
    await controller.requestDirections();
    final calculating = controller.calculateRoute();

    // showRoute must not have run yet: it is queued behind the blocked
    // showPlace, not racing it.
    await Future<void>.delayed(Duration.zero);
    expect(map.calls, isEmpty);

    map.unblock();
    await calculating;

    expect(map.calls, ['showPlace:Horn Center', 'showRoute:Horn Center']);
  });
}
