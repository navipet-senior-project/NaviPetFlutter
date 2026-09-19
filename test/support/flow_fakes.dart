// Shared fakes for the navigation flow controller tests.
//
// Task 11 (search + place preview) and Task 12 (route configuration and
// calculation) both need these. They live here instead of inside either
// test file so neither test file imports another test file.
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

class FakeSearchGateway implements CampusSearchGateway {
  List<CampusPlace> results = const [horn];

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async => results;

  @override
  Future<CampusPlace> place(String stableId) async {
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

  @override
  Future<LocationReading> current() async => reading;

  @override
  Stream<NavigationCoordinate> watch() => const Stream.empty();
}

class FakeRecents implements RecentSearchesGateway {
  List<CampusPlace> stored = const [];
  final List<String> saved = [];

  @override
  Future<List<CampusPlace>> list() async => stored;

  @override
  Future<void> save(CampusPlace place) async => saved.add(place.id);

  @override
  Future<void> clear() async => stored = const [];
}

class FakeRouteGateway implements OutdoorRouteGateway {
  Object? error;
  int calls = 0;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    String profile = 'walking',
  }) async {
    calls++;
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

  @override
  Future<void> showPlace(
    NavigationCoordinate coordinate, {
    required String label,
    required double bottomInset,
  }) async => calls.add('showPlace:$label');

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
