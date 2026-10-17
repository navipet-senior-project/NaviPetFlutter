import 'dart:async';

import 'package:flutter/foundation.dart';

import 'campus_bounds.dart';
import 'campus_place.dart';
import 'campus_search_controller.dart';
import 'campus_search_gateway.dart';
import 'location_service.dart';
import 'navi_map_controller.dart';
import 'navigation_flow_state.dart';
import 'navigation_models.dart';
import 'recent_searches_gateway.dart';
import 'route_repository.dart';
import 'route_progress.dart';
import 'travel_mode.dart';

/// Owns which part of the search-to-route flow the user is in.
///
/// Every asynchronous result is tagged with a generation so a reply that
/// arrives after the user moved on is discarded rather than applied.
class NavigationFlowController extends ChangeNotifier {
  NavigationFlowController({
    required this.search,
    required this.searchGateway,
    required this.recentSearches,
    required this.routes,
    required this.location,
    NaviMapController map = const _NoOpMapController(),
    // ignore: prefer_initializing_formals
  }) : _map = map {
    search.addListener(notifyListeners);
  }

  /// Height reserved for the bottom sheet when framing the map.
  static const placeSheetInset = 280.0;
  static const routeSheetInset = 320.0;

  final CampusSearchController search;
  final CampusSearchGateway searchGateway;
  final RecentSearchesGateway recentSearches;
  final RouteRepository routes;
  final LocationService location;

  // Not final: attachMap()/detachMap() swap it as the real Mapbox map is
  // created and torn down alongside MapScreen's own lifecycle, independent
  // of this controller's (app-scoped, longer-lived) lifecycle.
  NaviMapController _map;

  NavigationFlowState _state = const FlowIdle();
  List<CampusPlace> _recents = const [];
  String? _locationNotice;
  Future<void> _localRecentsReady = Future.value();
  int _recentRevision = 0;
  int _generation = 0;
  int _resumeGeneration = 0;
  StreamSubscription<NavigationCoordinate>? _guidanceLocation;
  NavigationCoordinate? _guidanceCoordinate;
  Object? _rerouteRequest;
  DateTime? _lastReroute;
  int _offRouteFixes = 0;

  // Chained so map mutations always apply in the order they were issued
  // rather than the order their underlying async work happens to finish.
  // Without this, a call queued after a slower one — e.g. requesting a new
  // route right after backing out of a drawn one — could have its result
  // silently overwritten when the slower, now-stale call finally lands.
  Future<void> _mapWork = Future<void>.value();

  NavigationFlowState get state => _state;

  List<CampusPlace> get recents => List.unmodifiable(_recents);

  String? get locationNotice => _locationNotice;

  /// Re-checks location after the app comes back to the foreground. The flow
  /// state is preserved: coming back from Settings should not throw away a
  /// route the user was reading.
  Future<void> handleAppResumed() async {
    final generation = ++_resumeGeneration;
    final reading = await location.current();
    if (generation != _resumeGeneration) return;

    final navigating = _state is FlowActiveNavigation;
    if (reading.usable &&
        (!navigating ||
            reading.availability == LocationAvailability.available)) {
      _locationNotice = null;
      notifyListeners();
      return;
    }
    _locationNotice = navigating
        ? 'Reacquiring GPS…'
        : 'Turn on location to route from here.';
    notifyListeners();
  }

  /// Hands the flow a live map to draw on, and re-issues whatever the
  /// current state should already be showing.
  ///
  /// `MapScreen` calls this from `onMapCreated`, once the real Mapbox map
  /// and its annotation managers exist — which is always *after* this
  /// controller itself was constructed (it's built in `main.dart`'s
  /// `initState`, before `MapWidget` fires `onMapCreated`) and, on every
  /// remount (e.g. `NaviBottomNav` navigating to `/checklist` or `/pet` and
  /// back — this controller is app-scoped and outlives any one `MapScreen`
  /// instance), after the app already has a destination or route showing.
  /// Without the replay, the map comes back blank under a route sheet that
  /// still claims a distance and duration.
  Future<void> attachMap(NaviMapController controller) {
    _map = controller;
    return _redraw();
  }

  /// Detaches whatever map is currently attached. `MapScreen` calls this
  /// from `dispose()`, so a `MapboxNaviMapController` wrapping an
  /// already-torn-down `MapboxMap` is never left as the delegate — an
  /// async reply (e.g. a `calculateRoute()` in flight when the user
  /// navigates away) that lands afterward is silently dropped instead of
  /// calling into a dead map surface.
  void detachMap() {
    _map = const _NoOpMapController();
  }

  /// Re-issues the draw for whatever [_state] already is, onto whatever
  /// [_map] currently is. Used by [attachMap] to catch a newly (re)attached
  /// map up to date; states with nothing to draw (idle, searching,
  /// configuring, calculating, error) are left alone.
  Future<void> _redraw() async {
    switch (_state) {
      case FlowPlacePreview(:final destination):
        if (destination == null) return;
        await _queueMap(
          () => _map.showPlace(
            destination.coordinate,
            label: destination.name,
            bottomInset: placeSheetInset,
          ),
        );
      case FlowRoutePreview(:final destination, :final origin, :final plan):
        await _redrawRoute(
          destination: destination,
          origin: origin,
          plan: plan,
        );
      case FlowRouteSteps(:final destination, :final origin, :final plan):
        await _redrawRoute(
          destination: destination,
          origin: origin,
          plan: plan,
        );
      case FlowActiveNavigation():
        await _drawGuidance();
      case FlowIdle():
      case FlowSearching():
      case FlowConfiguringRoute():
      case FlowCalculatingRoute():
      case FlowIndoorHandoff():
      case FlowError():
      // Nothing was ever drawn for these states, so there is nothing to
      // replay.
    }
  }

  Future<void> _redrawRoute({
    required NaviDestination destination,
    required RouteOrigin origin,
    required RoutePlan plan,
  }) async {
    final coordinate = origin.coordinate;
    if (coordinate == null) return;
    await _queueMap(
      () => _map.showRoute(
        plan,
        origin: coordinate,
        destination: destination,
        bottomInset: routeSheetInset,
      ),
    );
  }

  /// Returns the flow to [FlowIdle], drops the in-memory recents list, and
  /// resets the search — called when the signed-in identity changes (sign
  /// out, sign in, or a different user signing in on the same device).
  ///
  /// This controller is app-scoped and outlives any one session; without
  /// this, a new user briefly sees whatever the previous one had on
  /// screen — their destination, their origin, their recent searches —
  /// until they happen to interact with something that overwrites it.
  void resetForNewIdentity() {
    _generation++;
    _resumeGeneration++;
    _recents = const [];
    _recentRevision++;
    _locationNotice = null;
    _localRecentsReady = recentSearches.clearLocal().catchError((_) {
      // Recents are a convenience. A local-storage failure must not block
      // the rest of the identity reset or future search.
    });
    search.reset();
    _set(const FlowIdle());
    unawaited(_queueMap(() => _map.clear()));
  }

  void openSearch({bool pickingOrigin = false}) {
    final current = _state;
    // Picking an origin interrupts route configuration; remember it so
    // selecting a place — or backing out — can restore it. Re-entering the
    // picker (e.g. reopening the search screen while already picking) must
    // carry the existing snapshot forward: by then `_state` is already
    // `FlowSearching`, not the `FlowConfiguringRoute` being interrupted, so
    // recapturing only from a `FlowConfiguringRoute` would null it out and
    // reproduce the very bug this field exists to fix. When there is no
    // route to return to — from `FlowIdle`, mid-search, etc. — picking mode
    // is not entered at all; `pickingOrigin` is derived from this snapshot,
    // so there is no way to end up "picking" with nothing to restore.
    final configuringRoute = !pickingOrigin
        ? null
        : switch (current) {
            FlowConfiguringRoute() => current,
            FlowSearching(:final configuringRoute) => configuringRoute,
            _ => null,
          };
    _generation++;
    _set(FlowSearching(configuringRoute: configuringRoute));
    unawaited(loadRecents());
  }

  void queryChanged(String value) {
    final current = _state;
    if (current is FlowSearching) {
      _state = FlowSearching(
        query: value,
        configuringRoute: current.configuringRoute,
      );
    }
    search.queryChanged(value);
    notifyListeners();
  }

  Future<void> loadRecents() async {
    final generation = _generation;
    final revision = _recentRevision;
    try {
      await _localRecentsReady;
      final loaded = await recentSearches.list();
      // A list request can finish after a selection was saved. Do not let
      // that stale response overwrite the just-added local recent.
      if (generation != _generation || revision != _recentRevision) return;
      // The server may briefly lag behind the save. Keep local selections at
      // the front and add any server-only entries after them.
      _recents = [
        ..._recents,
        ...loaded.where(
          (remote) => !_recents.any((local) => local.id == remote.id),
        ),
      ].take(3).toList(growable: false);
      notifyListeners();
    } on Object {
      // Recents are a convenience; a failure must never block searching.
    }
  }

  Future<void> clearRecents() async {
    _recentRevision++;
    await recentSearches.clear();
    _recents = const [];
    notifyListeners();
  }

  Future<void> selectPlace(CampusPlace place) async {
    final requestState = _state;
    final generation = ++_generation;
    final query = switch (requestState) {
      FlowSearching(:final query) => query,
      _ => '',
    };

    // Move to the preview immediately. Suggestion resolution may require a
    // network round trip; waiting for it leaves the search sheet visible and
    // makes popular-location taps appear unresponsive while the keyboard is
    // open.
    if (requestState is FlowSearching && !requestState.pickingOrigin) {
      _set(
        FlowPlacePreview(
          place: place,
          destination: place.outdoorDestination == null
              ? null
              : place.toDestination(),
          previousQuery: query,
        ),
      );
    }

    // Local records are re-resolved so the preview shows current data.
    var resolved = place;
    if (place.isSuggestion) {
      resolved = await _resolveSuggestion(place);
    } else if (!place.external && place.source != 'cache') {
      try {
        resolved = await searchGateway.place(place.id);
      } on CampusSearchException {
        resolved = place;
      }
    }
    if (generation != _generation) return;

    final destination = resolved.outdoorDestination == null
        ? null
        : resolved.toDestination();

    // Picking an origin (rather than an ordinary destination search)
    // restores the interrupted route configuration with the new origin
    // instead of falling through to a plain place preview, which would
    // discard the destination and mode already chosen.
    final configuring = requestState is FlowSearching
        ? requestState.configuringRoute
        : null;
    if (configuring != null) {
      if (destination == null) {
        // A place with no map pin has no coordinate to route from. Stay in
        // picking mode — surface why, so the tap does not look like it did
        // nothing.
        _set(
          FlowSearching(
            query: query,
            configuringRoute: configuring,
            pickError: '${resolved.title} has no location on the map yet.',
          ),
        );
        return;
      }
      _set(configuring);
      setOrigin(PlaceOrigin(place: destination));
      _recordRecent(resolved);
      return;
    }

    _set(
      FlowPlacePreview(
        place: resolved,
        destination: destination,
        previousQuery: query,
      ),
    );

    _recordRecent(resolved);
    if (destination != null) {
      await _queueMap(
        () => _map.showPlace(
          destination.coordinate,
          label: destination.name,
          bottomInset: placeSheetInset,
        ),
        stillCurrent: () {
          final state = _state;
          return state is FlowPlacePreview && state.place.id == resolved.id;
        },
      );
    }
  }

  /// Suggestions that could not be matched to a campus record carry a
  /// synthetic id the backend rejects, so they are never recorded.
  void _recordRecent(CampusPlace place) {
    if (place.isSuggestion) return;
    _rememberRecent(place);
    unawaited(recentSearches.save(place));
  }

  /// Matches an app-made suggestion to the real campus record, by building
  /// code first and then by exact title.
  Future<CampusPlace> _resolveSuggestion(CampusPlace place) async {
    final code = place.buildingCode?.trim().toLowerCase();
    final title = place.title.trim().toLowerCase();
    final queries = [
      if (code != null && code.isNotEmpty) code,
      place.title.trim(),
    ];
    for (final query in queries) {
      final List<CampusPlace> found;
      try {
        found = filterToCampus(
          await searchGateway.autocomplete(query, limit: 5),
        );
      } on CampusSearchException {
        continue;
      }
      for (final candidate in found) {
        final candidateCode = candidate.buildingCode?.trim().toLowerCase();
        if ((code != null && code.isNotEmpty && candidateCode == code) ||
            candidate.title.trim().toLowerCase() == title) {
          return candidate;
        }
      }
    }
    return place;
  }

  void _rememberRecent(CampusPlace place) {
    if (place.external) return;
    _recentRevision++;
    _recents = [
      place,
      ..._recents.where((item) => item.id != place.id),
    ].take(3).toList(growable: false);
    notifyListeners();
  }

  Future<void> requestDirections() async {
    final current = _state;
    if (current is! FlowPlacePreview) return;
    final destination = current.destination;
    if (destination == null) return;

    final generation = ++_generation;
    final reading = await location.current();
    if (generation != _generation) return;

    final origin = reading.usable
        ? CurrentLocationOrigin(
            coordinate: reading.coordinate!,
            approximate: reading.isApproximate,
          )
        : const UnknownOrigin();

    _set(
      FlowConfiguringRoute(
        destination: destination,
        origin: origin,
        mode: enabledTravelModes.first,
        place: current.place,
      ),
    );
  }

  void setOrigin(RouteOrigin origin) {
    final current = _state;
    if (current is! FlowConfiguringRoute) return;
    _set(
      FlowConfiguringRoute(
        destination: current.destination,
        origin: origin,
        mode: current.mode,
        place: current.place,
      ),
    );
  }

  Future<void> setMode(TravelMode mode) async {
    if (!enabledTravelModes.contains(mode)) return;
    final current = _state;
    final (destination, origin, place) = switch (current) {
      FlowConfiguringRoute(:final destination, :final origin, :final place) => (
        destination,
        origin,
        place,
      ),
      FlowRoutePreview(:final destination, :final origin, :final place) => (
        destination,
        origin,
        place,
      ),
      FlowRouteSteps(:final destination, :final origin, :final place) => (
        destination,
        origin,
        place,
      ),
      _ => (null, null, null),
    };
    if (destination == null || origin == null) return;

    _set(
      FlowConfiguringRoute(
        destination: destination,
        origin: origin,
        mode: mode,
        place: place,
      ),
    );
    await calculateRoute();
  }

  Future<void> calculateRoute() async {
    final current = _state;
    if (current is! FlowConfiguringRoute) return;
    final origin = current.origin.coordinate;
    if (origin == null) return;

    final generation = ++_generation;
    _set(
      FlowCalculatingRoute(
        destination: current.destination,
        origin: current.origin,
        mode: current.mode,
        place: current.place,
      ),
    );

    try {
      final plan = await routes.plan(
        origin: origin,
        destination: current.destination,
        mode: current.mode,
      );
      if (generation != _generation) return;
      _set(
        FlowRoutePreview(
          destination: current.destination,
          origin: current.origin,
          plan: plan,
          place: current.place,
        ),
      );
      await _queueMap(
        () => _map.showRoute(
          plan,
          origin: origin,
          destination: current.destination,
          bottomInset: routeSheetInset,
        ),
        stillCurrent: () => generation == _generation,
      );
    } on RouteFailure catch (error) {
      if (generation != _generation) return;
      _set(FlowError(message: error.message, previous: current));
    }
  }

  Future<void> selectRoute(int index) async {
    final current = _state;
    if (current is! FlowRoutePreview) return;
    final plan = current.plan.select(index);
    _set(
      FlowRoutePreview(
        destination: current.destination,
        origin: current.origin,
        plan: plan,
        place: current.place,
      ),
    );
    final origin = current.origin.coordinate;
    if (origin == null) return;
    await _queueMap(
      () => _map.showRoute(
        plan,
        origin: origin,
        destination: current.destination,
        bottomInset: routeSheetInset,
      ),
    );
  }

  void showSteps() {
    final current = _state;
    if (current is! FlowRoutePreview) return;
    _set(
      FlowRouteSteps(
        destination: current.destination,
        origin: current.origin,
        plan: current.plan,
        place: current.place,
      ),
    );
  }

  void hideSteps() {
    final current = _state;
    if (current is! FlowRouteSteps) return;
    _set(
      FlowRoutePreview(
        destination: current.destination,
        origin: current.origin,
        plan: current.plan,
        place: current.place,
      ),
    );
  }

  Future<void> startRoute() async {
    final current = _state;
    final (destination, origin, plan, place) = switch (current) {
      FlowRoutePreview(
        :final destination,
        :final origin,
        :final plan,
        :final place,
      ) =>
        (destination, origin, plan, place),
      FlowRouteSteps(
        :final destination,
        :final origin,
        :final plan,
        :final place,
      ) =>
        (destination, origin, plan, place),
      _ => (null, null, null, null),
    };
    if (destination == null || origin == null || plan == null) return;

    // Guidance is only offered when the route starts where the user is.
    if (!origin.canStartGuidance) return;

    // Invalidate any preview camera operation that is still queued. The
    // guidance camera must be the next camera state the user sees.
    _generation++;
    _set(
      FlowActiveNavigation(
        destination: destination,
        origin: origin,
        plan: plan,
        place: place,
      ),
    );
    _guidanceCoordinate = origin.coordinate;
    _lastReroute = null;
    _offRouteFixes = 0;
    _guidanceLocation = location.watch().listen(
      (coordinate) => unawaited(updateNavigationLocation(coordinate)),
      onError: (Object error) {
        if (_state is! FlowActiveNavigation) return;
        _locationNotice = 'Reacquiring GPS...';
        notifyListeners();
      },
    );
    await _drawGuidance();
  }

  /// Only active guidance consumes GPS fixes; previews keep their chosen route.
  Future<void> updateNavigationLocation(NavigationCoordinate coordinate) async {
    final current = _state;
    if (current is! FlowActiveNavigation) return;
    _guidanceCoordinate = coordinate;
    _locationNotice = null;
    final progress = RouteProgress(current.plan.selected, coordinate);
    if (progress.distanceFromRoute > 35) {
      _offRouteFixes++;
      await _queueMap(
        () => _map.followUser(coordinate),
        stillCurrent: () => _state is FlowActiveNavigation,
      );
      if (_offRouteFixes >= 2) await _reroute(coordinate);
      return;
    }
    _offRouteFixes = 0;
    // A fix back on the path invalidates any reroute still in flight.
    _rerouteRequest = null;
    _set(
      FlowActiveNavigation(
        destination: current.destination,
        origin: current.origin,
        plan: current.plan,
        place: current.place,
        stepIndex: progress.stepIndex,
        remainingRoute: progress.remaining,
      ),
    );
    await _drawGuidance();
  }

  Future<void> _reroute(NavigationCoordinate coordinate) async {
    final current = _state;
    if (current is! FlowActiveNavigation || _rerouteRequest != null) return;
    final now = DateTime.now();
    if (_lastReroute != null &&
        now.difference(_lastReroute!) < const Duration(seconds: 10)) {
      return;
    }
    _lastReroute = now;
    final request = Object();
    _rerouteRequest = request;
    final generation = _generation;
    try {
      final plan = await routes.plan(
        origin: coordinate,
        destination: current.destination,
        mode: current.plan.mode,
      );
      if (generation != _generation ||
          _rerouteRequest != request ||
          _state is! FlowActiveNavigation) {
        return;
      }
      _set(
        FlowActiveNavigation(
          destination: current.destination,
          origin: CurrentLocationOrigin(coordinate: coordinate),
          plan: plan,
          place: current.place,
        ),
      );
      _locationNotice = null;
      _offRouteFixes = 0;
      await updateNavigationLocation(_guidanceCoordinate ?? coordinate);
    } on RouteFailure {
      if (generation != _generation || _rerouteRequest != request) return;
      _locationNotice = 'Could not reroute. Retrying as you move.';
      notifyListeners();
    } finally {
      if (_rerouteRequest == request) _rerouteRequest = null;
    }
  }

  Future<void> _drawGuidance() => _queueMap(() async {
    final current = _state;
    if (current is! FlowActiveNavigation) return;
    final coordinate = _guidanceCoordinate ?? current.origin.coordinate;
    if (coordinate == null) return;
    final map = _map;
    if (map is GuidanceMapController) {
      await (map as GuidanceMapController).updateGuidance(
        current.remainingRoute ?? current.plan.selected,
        destination: current.destination,
      );
    }
    await map.followUser(coordinate);
  });

  Future<void> endRoute() async {
    final current = _state;
    if (current is! FlowActiveNavigation) return;
    _generation++;
    _set(const FlowIdle());
    search.reset();
    await _queueMap(() => _map.clear());
  }

  Future<void> retry() async {
    final current = _state;
    if (current is! FlowError) return;
    final previous = current.previous;
    _set(previous);
    if (previous is FlowConfiguringRoute) await calculateRoute();
  }

  void back() {
    switch (_state) {
      case FlowIdle():
        return;
      case FlowSearching(:final configuringRoute):
        _generation++;
        if (configuringRoute != null) {
          // Backing out of the origin picker returns to the route being
          // configured, not to idle — leaving picking mode must not
          // reproduce the bug this field exists to fix.
          _set(configuringRoute);
        } else {
          _set(const FlowIdle());
          unawaited(_queueMap(() => _map.clear()));
        }
      case FlowPlacePreview(:final previousQuery):
        _generation++;
        _set(FlowSearching(query: previousQuery));
      case FlowConfiguringRoute(:final place, :final destination):
        _generation++;
        _set(
          FlowPlacePreview(
            place: place ?? _placeFor(destination),
            destination: destination,
          ),
        );
      case FlowCalculatingRoute(
        :final place,
        :final destination,
        :final origin,
        :final mode,
      ):
        _generation++;
        _set(
          FlowConfiguringRoute(
            destination: destination,
            origin: origin,
            mode: mode,
            place: place,
          ),
        );
      case FlowRoutePreview(:final place, :final destination):
        _generation++;
        _set(
          FlowPlacePreview(
            place: place ?? _placeFor(destination),
            destination: destination,
          ),
        );
        // The drawn route must not survive behind the place sheet. Queued
        // rather than fired directly, so it cannot race a map call issued
        // moments later (e.g. a fresh calculateRoute()) and lose — without
        // the queue, whichever call's underlying async work happens to
        // finish last wins, not whichever was issued last.
        unawaited(
          _queueMap(
            () => _map.showPlace(
              destination.coordinate,
              label: destination.name,
              bottomInset: placeSheetInset,
            ),
            stillCurrent: () {
              final state = _state;
              return state is FlowPlacePreview &&
                  state.place.id ==
                      (place?.id ?? destination.id ?? destination.name);
            },
          ),
        );
      case FlowRouteSteps():
        // Identical to the user tapping the steps sheet's close affordance
        // — one behaviour per transition, not a second copy of it.
        hideSteps();
      case FlowActiveNavigation(
        :final destination,
        :final origin,
        :final plan,
        :final place,
      ):
        // Back (and the "Overview" button) leaves guidance but keeps the
        // route. Only an explicit, confirmed endRoute() discards it.
        _generation++;
        _set(
          FlowRoutePreview(
            destination: destination,
            origin: origin,
            plan: plan,
            place: place,
          ),
        );
        unawaited(
          _redrawRoute(destination: destination, origin: origin, plan: plan),
        );
      case FlowIndoorHandoff():
        _generation++;
        _set(const FlowIdle());
      case FlowError(:final previous):
        _generation++;
        _set(previous);
    }
  }

  void _set(NavigationFlowState next) {
    if (next is! FlowActiveNavigation) {
      _guidanceLocation?.cancel();
      _guidanceLocation = null;
      _rerouteRequest = null;
    }
    _state = next;
    notifyListeners();
  }

  /// Queues [action] behind whatever map work is already in flight, so map
  /// mutations complete in request order instead of finish order.
  Future<void> _queueMap(
    Future<void> Function() action, {
    bool Function()? stillCurrent,
  }) {
    final result = _mapWork.then<void>((_) async {
      if (stillCurrent != null && !stillCurrent()) return;
      await action();
    });
    // The queue itself must stay resolved even when a call fails, or every
    // later map call would wait forever behind a permanently-rejected
    // future. The caller's own awaited [result] still carries the error.
    _mapWork = result.catchError((_) {});
    return result;
  }

  /// Rebuilds a minimal place record when the flow only kept the destination.
  CampusPlace _placeFor(NaviDestination destination) => CampusPlace(
    id: destination.id ?? destination.name,
    type: destination.type ?? CampusDestinationType.building,
    title: destination.name,
    subtitle: destination.address,
    source: 'cache',
    buildingCode: destination.buildingCode,
    roomNumber: destination.roomNumber,
    floorNumber: destination.floorNumber,
    outdoorDestination: destination.coordinate,
    indoorDestinationId: destination.indoorDestinationId,
  );

  @override
  void dispose() {
    _generation++;
    _guidanceLocation?.cancel();
    _rerouteRequest = null;
    search.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Silently drops every call. The flow's map until [NavigationFlowController.
/// attachMap] hands it a real one — deliberately a no-op, not a queue:
/// nothing issued before attachment is replayed. [NavigationFlowController.
/// attachMap] instead re-issues the draw for whatever state the flow is
/// already in when it's called, which is what "catching up" a newly (or
/// freshly re-) attached map actually requires; queueing every call made
/// while unattached would replay stale intermediate states on top of it.
class _NoOpMapController implements NaviMapController {
  const _NoOpMapController();

  @override
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  }) async {}

  @override
  Future<void> showRoute(
    RoutePlan plan, {
    required NavigationCoordinate origin,
    required NaviDestination destination,
    required double bottomInset,
  }) async {}

  @override
  Future<void> followUser(
    NavigationCoordinate coordinate, {
    double? bearing,
  }) async {}

  @override
  Future<void> clear() async {}
}
