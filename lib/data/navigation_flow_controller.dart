import 'dart:async';

import 'package:flutter/foundation.dart';

import 'campus_place.dart';
import 'campus_search_controller.dart';
import 'campus_search_gateway.dart';
import 'location_service.dart';
import 'navi_map_controller.dart';
import 'navigation_flow_state.dart';
import 'navigation_models.dart';
import 'recent_searches_gateway.dart';
import 'route_repository.dart';
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
    required NaviMapController map,
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
  final NaviMapController _map;

  NavigationFlowState _state = const FlowIdle();
  List<CampusPlace> _recents = const [];
  int _generation = 0;

  // Chained so map mutations always apply in the order they were issued
  // rather than the order their underlying async work happens to finish.
  // Without this, a call queued after a slower one — e.g. requesting a new
  // route right after backing out of a drawn one — could have its result
  // silently overwritten when the slower, now-stale call finally lands.
  Future<void> _mapWork = Future<void>.value();

  NavigationFlowState get state => _state;

  List<CampusPlace> get recents => List.unmodifiable(_recents);

  /// The map seam this flow drives. Exposed so `MapScreen` can hand a
  /// `DeferredMapController` (built before the real Mapbox map exists) its
  /// real delegate once `onMapCreated` fires — the flow is constructed
  /// ahead of the map, so something has to bridge the two.
  NaviMapController get map => _map;

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
    try {
      final loaded = await recentSearches.list();
      _recents = loaded;
      notifyListeners();
    } on Object {
      // Recents are a convenience; a failure must never block searching.
    }
  }

  Future<void> clearRecents() async {
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

    // Local records are re-resolved so the preview shows current data.
    var resolved = place;
    if (!place.external && place.source != 'cache') {
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
      unawaited(recentSearches.save(resolved));
      return;
    }

    _set(
      FlowPlacePreview(
        place: resolved,
        destination: destination,
        previousQuery: query,
      ),
    );

    unawaited(recentSearches.save(resolved));
    if (destination != null) {
      await _queueMap(
        () => _map.showPlace(
          destination.coordinate,
          label: destination.name,
          bottomInset: placeSheetInset,
        ),
      );
    }
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

    _set(
      FlowActiveNavigation(
        destination: destination,
        origin: origin,
        plan: plan,
        place: place,
      ),
    );
    final coordinate = origin.coordinate;
    if (coordinate != null) {
      await _queueMap(() => _map.followUser(coordinate));
    }
  }

  Future<void> endRoute() async {
    final current = _state;
    if (current is! FlowActiveNavigation) return;
    _set(
      FlowRoutePreview(
        destination: current.destination,
        origin: current.origin,
        plan: current.plan,
        place: current.place,
      ),
    );
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
          ),
        );
      case FlowRouteSteps():
        // Identical to the user tapping the steps sheet's close affordance
        // — one behaviour per transition, not a second copy of it.
        hideSteps();
      case FlowActiveNavigation():
        // Identical to the user tapping "end navigation". Firing without
        // awaiting is only safe because endRoute() has no `await` before
        // its `_set` call, so the state update still lands this turn. If
        // endRoute() ever gains an await before that `_set`, back() would
        // silently stop updating state synchronously and no test here
        // would catch it.
        unawaited(endRoute());
      case FlowIndoorHandoff():
        _generation++;
        _set(const FlowIdle());
      case FlowError(:final previous):
        _generation++;
        _set(previous);
    }
  }

  void _set(NavigationFlowState next) {
    _state = next;
    notifyListeners();
  }

  /// Queues [action] behind whatever map work is already in flight, so map
  /// mutations complete in request order instead of finish order.
  Future<void> _queueMap(Future<void> Function() action) {
    final result = _mapWork.then((_) => action());
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
    search.removeListener(notifyListeners);
    super.dispose();
  }
}
