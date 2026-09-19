// Shared fakes for the navigation flow controller tests.
//
// Task 11 (search + place preview) and Task 12 (route configuration and
// calculation) both need these. They live here instead of inside either
// test file so neither test file imports another test file.
import 'dart:async';

import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/campus_search_controller.dart';
import 'package:navipet/data/campus_search_gateway.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navi_map_controller.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/outdoor_route_gateway.dart';
import 'package:navipet/data/recent_searches_gateway.dart';
import 'package:navipet/data/route_repository.dart';
import 'package:navipet/data/search_location_provider.dart';

const hornCoordinate = NavigationCoordinate(
  latitude: 33.78307046,
  longitude: -118.11456126,
);

const horn = CampusPlace(
  id: '00000000-0000-4000-8000-000000000001',
  type: CampusDestinationType.building,
  title: 'Horn Center',
  subtitle: 'HC',
  source: 'csulb',
  buildingCode: 'HC',
  outdoorDestination: hornCoordinate,
);

const unmapped = CampusPlace(
  id: '00000000-0000-4000-8000-000000000002',
  type: CampusDestinationType.building,
  title: 'Vivian Engineering Center',
  subtitle: 'VEC',
  source: 'csulb',
  buildingCode: 'VEC',
);

const libraryCoordinate = NavigationCoordinate(
  latitude: 33.78854,
  longitude: -118.11407,
);

/// A second mapped place, distinct from [horn], for tests that pick an
/// origin rather than a destination.
const library = CampusPlace(
  id: '00000000-0000-4000-8000-000000000003',
  type: CampusDestinationType.building,
  title: 'University Library',
  subtitle: 'LIB',
  source: 'csulb',
  buildingCode: 'LIB',
  outdoorDestination: libraryCoordinate,
);

class FakeSearchGateway implements CampusSearchGateway {
  List<CampusPlace> results = const [horn];

  final Map<String, Completer<void>> _blocked = {};

  /// Test control: makes `place(id)` wait until [unblockPlace] releases the
  /// same id, so a test can hold one `selectPlace` in flight while a second,
  /// newer one runs to completion — proving the stale-generation guard.
  void blockPlace(String id) => _blocked[id] = Completer<void>();

  void unblockPlace(String id) => _blocked.remove(id)?.complete();

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async => results;

  @override
  Future<CampusPlace> place(String stableId) async {
    final gate = _blocked[stableId];
    if (gate != null) await gate.future;
    for (final item in results) {
      if (item.id == stableId) return item;
    }
    // Mirrors HttpCampusSearchGateway's behavior for an id the backend does
    // not recognize (a 404 decoded as CampusSearchException), rather than
    // letting firstWhere's StateError escape uncaught.
    throw const CampusSearchException(
      failure: CampusSearchFailure.api,
      message: 'Campus place details were unavailable.',
    );
  }
}

class FakeLocationService implements LocationService {
  LocationReading reading = const LocationReading(
    availability: LocationAvailability.available,
    coordinate: NavigationCoordinate(latitude: 33.7840, longitude: -118.1150),
  );

  Completer<void>? _blocked;
  final List<Completer<LocationReading>> _queuedReadings = [];

  /// Test control: queues a specific future reply for the next `current()`
  /// call, allowing overlapping requests to complete out of order.
  Completer<LocationReading> queueReading() {
    final completer = Completer<LocationReading>();
    _queuedReadings.add(completer);
    return completer;
  }

  /// Test control: makes `current()` wait until [unblock] releases it, so a
  /// test can hold one `requestDirections` in flight while a second, newer
  /// flow action runs to completion first — proving the stale-generation
  /// guard.
  void block() => _blocked = Completer<void>();

  void unblock() {
    _blocked?.complete();
    _blocked = null;
  }

  @override
  Future<LocationReading> current() async {
    if (_queuedReadings.isNotEmpty) {
      return _queuedReadings.removeAt(0).future;
    }
    final gate = _blocked;
    if (gate != null) await gate.future;
    return reading;
  }

  @override
  Stream<NavigationCoordinate> watch() => const Stream.empty();

  /// Test control: records what was primed, so a test can assert on it
  /// directly instead of only inferring priming happened.
  NavigationCoordinate? primedLastKnown;

  @override
  void primeLastKnown(NavigationCoordinate coordinate) {
    primedLastKnown = coordinate;
  }
}

class FakeRecents implements RecentSearchesGateway {
  List<CampusPlace> stored = const [];
  final List<String> saved = [];

  @override
  Future<List<CampusPlace>> list() async => stored;

  @override
  Future<void> save(CampusPlace place) async {
    // Matches HttpRecentSearchesGateway.save(): external (Mapbox) results
    // are not CSULB records and are never stored server-side.
    if (place.external) return;
    saved.add(place.id);
  }

  @override
  Future<void> clear() async => stored = const [];

  @override
  Future<void> clearLocal() async => stored = const [];
}

class FakeRouteGateway implements OutdoorRouteGateway {
  Object? error;
  int calls = 0;

  Completer<void>? _blocked;

  /// Test control: makes `getRoute` wait until [unblock] releases it, so a
  /// test can hold one `calculateRoute` in flight while a second, newer flow
  /// action runs to completion first — proving the stale-generation guard.
  void block() => _blocked = Completer<void>();

  void unblock() {
    _blocked?.complete();
    _blocked = null;
  }

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    String profile = 'walking',
  }) async {
    calls++;
    final gate = _blocked;
    if (gate != null) await gate.future;
    final failure = error;
    if (failure != null) throw failure;
    return const NavigationRoute(
      coordinates: [hornCoordinate],
      steps: [
        NavigationStep(
          instruction: 'Walk north',
          distanceMeters: 120,
          durationSeconds: 90,
          maneuver: hornCoordinate,
          maneuverType: 'depart',
        ),
      ],
      distanceMeters: 210,
      durationSeconds: 180,
    );
  }
}

class RecordingMap implements NaviMapController {
  final List<String> calls = [];

  Completer<void>? _blockedShowPlace;

  /// Test control: makes the next `showPlace` call wait until [unblock]
  /// releases it, so a test can force two competing map operations to
  /// resolve in request order rather than in whatever order the fakes'
  /// instant, no-delay futures happen to settle — proving the `_mapWork`
  /// serialization queue, not just the ordering luck of the event loop.
  void blockShowPlace() => _blockedShowPlace = Completer<void>();

  void unblock() {
    _blockedShowPlace?.complete();
    _blockedShowPlace = null;
  }

  @override
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  }) async {
    final gate = _blockedShowPlace;
    if (gate != null) await gate.future;
    calls.add('showPlace:$label');
  }

  @override
  Future<void> showRoute(
    RoutePlan plan, {
    required NavigationCoordinate origin,
    required NaviDestination destination,
    required double bottomInset,
  }) async => calls.add('showRoute:${destination.name}');

  @override
  Future<void> followUser(
    NavigationCoordinate coordinate, {
    double? bearing,
  }) async => calls.add('followUser');

  @override
  Future<void> clear() async => calls.add('clear');
}

NavigationFlowController build({
  FakeSearchGateway? search,
  FakeLocationService? location,
  FakeRecents? recents,
  FakeRouteGateway? routes,
  RecordingMap? map,
}) {
  final searchGateway = search ?? FakeSearchGateway();
  return NavigationFlowController(
    search: CampusSearchController(
      gateway: searchGateway,
      location: _NoProximity(),
      debounce: const Duration(milliseconds: 10),
    ),
    searchGateway: searchGateway,
    recentSearches: recents ?? FakeRecents(),
    routes: RouteRepository(gateway: routes ?? FakeRouteGateway()),
    location: location ?? FakeLocationService(),
    map: map ?? RecordingMap(),
  );
}

class _NoProximity implements SearchLocationProvider {
  @override
  Future<SearchLocationResult> locationFor(String normalizedQuery) async =>
      const SearchLocationResult.notRequired();
}
