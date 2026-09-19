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

  NavigationFlowState get state => _state;

  List<CampusPlace> get recents => List.unmodifiable(_recents);

  void openSearch({bool pickingOrigin = false}) {
    _generation++;
    _set(FlowSearching(pickingOrigin: pickingOrigin));
    unawaited(loadRecents());
  }

  void queryChanged(String value) {
    final current = _state;
    if (current is FlowSearching) {
      _state = FlowSearching(
        query: value,
        pickingOrigin: current.pickingOrigin,
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
    final generation = ++_generation;
    final query = switch (_state) {
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

    _set(
      FlowPlacePreview(
        place: resolved,
        destination: destination,
        previousQuery: query,
      ),
    );

    unawaited(recentSearches.save(resolved));
    if (destination != null) {
      await _map.showPlace(
        destination.coordinate,
        label: destination.name,
        bottomInset: placeSheetInset,
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
      await _map.showRoute(
        plan,
        origin: origin,
        destination: current.destination,
        bottomInset: routeSheetInset,
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
    await _map.showRoute(
      plan,
      origin: origin,
      destination: current.destination,
      bottomInset: routeSheetInset,
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
    if (coordinate != null) await _map.followUser(coordinate);
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
      case FlowSearching():
        _generation++;
        _set(const FlowIdle());
        unawaited(_map.clear());
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
      case FlowRouteSteps(
        :final place,
        :final destination,
        :final origin,
        :final plan,
      ):
        _generation++;
        _set(
          FlowRoutePreview(
            destination: destination,
            origin: origin,
            plan: plan,
            place: place,
          ),
        );
      case FlowActiveNavigation(
        :final place,
        :final destination,
        :final origin,
        :final plan,
      ):
        _generation++;
        _set(
          FlowRoutePreview(
            destination: destination,
            origin: origin,
            plan: plan,
            place: place,
          ),
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
    _state = next;
    notifyListeners();
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
