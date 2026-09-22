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

  // Fix-round 3 additions: the review found MapScreen's map delegate was a
  // one-way assignment with no replay on remount (NaviBottomNav disposes
  // MapScreen navigating to /checklist or /pet while this app-scoped flow
  // keeps its state) and no teardown on dispose (a reply landing after
  // navigating away would call into a MapboxNaviMapController wrapping an
  // already-dead map). attachMap()/detachMap() replace that one-way
  // assignment; these tests exercise them directly, independent of
  // MapScreen/Mapbox (which the widget tests in map_screen_flow_test.dart
  // can't reach — onMapCreated never fires without a real platform view).

  test('attaching a map redraws the current place preview', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);

    final newMap = harness.RecordingMap();
    await controller.attachMap(newMap);

    expect(newMap.calls, ['showPlace:Horn Center']);
  });

  test('attaching a map redraws the current route preview', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    final newMap = harness.RecordingMap();
    await controller.attachMap(newMap);

    expect(newMap.calls, ['showRoute:Horn Center']);
  });

  test('attaching a map redraws the expanded steps sheet as a route', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    controller.showSteps();

    final newMap = harness.RecordingMap();
    await controller.attachMap(newMap);

    expect(newMap.calls, ['showRoute:Horn Center']);
  });

  test('attaching a map while active navigation follows the user', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();

    final newMap = harness.RecordingMap();
    await controller.attachMap(newMap);

    expect(newMap.calls, ['followUser']);
  });

  test('attaching a map while idle, searching, configuring, or calculating '
      'draws nothing', () async {
    final controller = harness.build();
    final idleMap = harness.RecordingMap();
    await controller.attachMap(idleMap);
    expect(idleMap.calls, isEmpty);

    controller.openSearch();
    final searchingMap = harness.RecordingMap();
    await controller.attachMap(searchingMap);
    expect(searchingMap.calls, isEmpty);

    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    final configuringMap = harness.RecordingMap();
    await controller.attachMap(configuringMap);
    expect(configuringMap.calls, isEmpty);
  });

  test(
    'detaching the map stops further calls from reaching the old delegate',
    () async {
      final map = harness.RecordingMap();
      final controller = harness.build(map: map)..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
      map.calls.clear();

      controller.detachMap();
      // selectRoute() always calls _map.showRoute() when the origin has a
      // coordinate (see selectRoute's implementation) — exactly the kind of
      // call that, before detachMap(), would have reached a torn-down real
      // map after the user navigated away.
      await controller.selectRoute(0);

      expect(map.calls, isEmpty);
    },
  );

  test(
    'reattaching after detach draws on the new map, not the detached one',
    () async {
      final oldMap = harness.RecordingMap();
      final controller = harness.build(map: oldMap)..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
      oldMap.calls.clear();
      controller.detachMap();

      final newMap = harness.RecordingMap();
      await controller.attachMap(newMap);

      expect(newMap.calls, ['showRoute:Horn Center']);
      expect(oldMap.calls, isEmpty);
    },
  );

  // Fix-round 3 additions, part 2: the flow controller is app-scoped and
  // outlives any one signed-in session (main.dart builds it once). Without
  // resetForNewIdentity(), signing out mid-route and back in as someone
  // else would show the new user the previous user's destination, origin,
  // and recent searches.

  test('resetForNewIdentity returns to idle and clears the map', () async {
    final map = harness.RecordingMap();
    final controller = harness.build(map: map)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    map.calls.clear();

    controller.resetForNewIdentity();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, isA<FlowIdle>());
    expect(map.calls, contains('clear'));
  });

  test('resetForNewIdentity drops the previous user\'s recents', () async {
    final recents = harness.FakeRecents()..stored = const [harness.horn];
    final controller = harness.build(recents: recents);
    await controller.loadRecents();
    expect(controller.recents, isNotEmpty);

    controller.resetForNewIdentity();

    expect(controller.recents, isEmpty);
  });

  test(
    'resetForNewIdentity prevents cached recents from reappearing on reload',
    () async {
      final recents = harness.FakeRecents()..stored = const [harness.horn];
      final controller = harness.build(recents: recents);

      controller.resetForNewIdentity();
      await controller.loadRecents();

      expect(controller.recents, isEmpty);
    },
  );

  test(
    'resetForNewIdentity discards a route calculation already in flight',
    () async {
      final routes = harness.FakeRouteGateway()..block();
      final controller = harness.build(routes: routes)..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      final pending = controller.calculateRoute();

      controller.resetForNewIdentity();
      routes.unblock();
      await pending;

      // The stale reply from the previous user's in-flight calculation
      // must not resurrect a route preview on top of the reset.
      expect(controller.state, isA<FlowIdle>());
    },
  );

  test('resuming keeps the current flow state', () async {
    final controller = harness.build()..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();

    await controller.handleAppResumed();

    expect(controller.state, isA<FlowRoutePreview>());
  });

  test('resuming with a lost permission posts a notice', () async {
    final location = harness.FakeLocationService();
    final controller = harness.build(location: location)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    location.reading = const LocationReading(
      availability: LocationAvailability.permissionDenied,
    );
    await controller.handleAppResumed();

    expect(controller.locationNotice, 'Turn on location to route from here.');
  });

  test('resuming during navigation without a fix warns about GPS', () async {
    final location = harness.FakeLocationService();
    final controller = harness.build(location: location)..openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
    await controller.startRoute();

    location.reading = const LocationReading(
      availability: LocationAvailability.unavailable,
    );
    await controller.handleAppResumed();

    expect(controller.locationNotice, 'Reacquiring GPS…');
    expect(controller.state, isA<FlowActiveNavigation>());
  });

  test('an older resume check cannot overwrite a newer result', () async {
    final location = harness.FakeLocationService();
    final olderReading = location.queueReading();
    final controller = harness.build(location: location);

    final olderResume = controller.handleAppResumed();
    await controller.handleAppResumed();
    expect(controller.locationNotice, isNull);

    olderReading.complete(
      const LocationReading(
        availability: LocationAvailability.permissionDenied,
      ),
    );
    await olderResume;

    expect(controller.locationNotice, isNull);
  });

  test(
    'an approximate fix during navigation warns that GPS is stale',
    () async {
      final location = harness.FakeLocationService();
      final controller = harness.build(location: location)..openSearch();
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
      await controller.startRoute();

      location.reading = const LocationReading(
        availability: LocationAvailability.approximate,
        coordinate: NavigationCoordinate(latitude: 33.784, longitude: -118.115),
      );
      await controller.handleAppResumed();

      expect(controller.locationNotice, 'Reacquiring GPS…');
    },
  );

  test('identity reset discards a resume check already in flight', () async {
    final location = harness.FakeLocationService();
    final pendingReading = location.queueReading();
    final controller = harness.build(location: location);

    final pendingResume = controller.handleAppResumed();
    controller.resetForNewIdentity();
    pendingReading.complete(
      const LocationReading(
        availability: LocationAvailability.permissionDenied,
      ),
    );
    await pendingResume;

    expect(controller.locationNotice, isNull);
    expect(controller.state, isA<FlowIdle>());
  });
}
