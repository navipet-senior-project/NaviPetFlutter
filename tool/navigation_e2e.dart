// Debug-only simulator target. Production uses main.dart.
// Building outlines are OpenStreetMap test data, not backend footprints.
// Outdoor points match campus_destinations. Routes and GPS policy are fixtures.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/campus_search_controller.dart';
import 'package:navipet/data/campus_search_gateway.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/mapbox_config.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/outdoor_route_gateway.dart';
import 'package:navipet/data/recent_searches_gateway.dart';
import 'package:navipet/data/route_repository.dart';
import 'package:navipet/data/search_location_provider.dart';
import 'package:navipet/screens/map_screen.dart';
import 'package:navipet/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'osm_test_footprints.dart';

final mockBuilding = CampusPlace(
  id: 'osm-cob',
  type: CampusDestinationType.building,
  title: 'College of Business',
  subtitle: 'OSM outline for verification, not a backend footprint',
  source: 'cache',
  buildingCode: 'COB',
  outdoorDestination: collegeOfBusinessOutdoor,
  footprint: osmTestFootprint('College of Business'),
);

Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('Navigation fixtures require a debug build.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  MapboxOptions.setAccessToken(mapboxPublicToken);
  runApp(const NavigationEvidenceApp());
}

class NavigationEvidenceApp extends StatefulWidget {
  const NavigationEvidenceApp({super.key});
  @override
  State<NavigationEvidenceApp> createState() => _NavigationEvidenceAppState();
}

class _NavigationEvidenceAppState extends State<NavigationEvidenceApp> {
  final appState = AppState();
  final location = MockLocation();
  final routes = MockRoutes();
  late final flow = NavigationFlowController(
    search: CampusSearchController(
      gateway: MockSearch(),
      location: NoProximity(),
    ),
    searchGateway: MockSearch(),
    recentSearches: MockRecents(),
    routes: RouteRepository(gateway: routes),
    location: location,
  );
  void scenario(String name) {
    location.scenario = name;
    flow.resetForNewIdentity();
    routes.calls = 0;
    setState(() {});
  }

  @override
  void dispose() {
    flow.dispose();
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: appState),
      ChangeNotifierProvider.value(value: flow),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.amber),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const Text(
                    'Mock navigation verification',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Outlines: OpenStreetMap, not backend',
                    style: TextStyle(fontSize: 12),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final name in ['Outside', 'Inside', 'Uncertain'])
                        TextButton(
                          onPressed: () => scenario(name),
                          child: Text(name),
                        ),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: flow,
                    builder: (_, _) => Text(
                      'State: ${flow.status.name}; route requests: ${routes.calls}',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: MapScreen(controller: flow)),
          ],
        ),
      ),
    ),
  );
}

class MockLocation implements LocationService {
  String scenario = 'Outside';
  @override
  Future<LocationReading> current() async => LocationReading(
    availability: LocationAvailability.available,
    coordinate: switch (scenario) {
      'Outside' => hornCenterOutdoor,
      'Inside' => insideCollegeOfBusiness,
      _ => collegeOfBusinessOutdoor,
    },
    timestamp: DateTime.now(),
    accuracyMeters: scenario == 'Uncertain' ? 80 : 5,
  );
  @override
  Stream<NavigationCoordinate> watch() => const Stream.empty();
  @override
  void primeLastKnown(NavigationCoordinate coordinate) {}
}

class MockSearch implements CampusSearchGateway {
  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async => query.toLowerCase().contains('business') ? [mockBuilding] : [];
  @override
  Future<CampusPlace> place(String stableId) async => mockBuilding;
}

class NoProximity implements SearchLocationProvider {
  @override
  Future<SearchLocationResult> locationFor(String normalizedQuery) async =>
      const SearchLocationResult.notRequired();
}

class MockRecents implements RecentSearchesGateway {
  @override
  Future<List<CampusPlace>> list() async => [];
  @override
  Future<void> save(CampusPlace place) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearLocal() async {}
}

class MockRoutes implements OutdoorRouteGateway {
  int calls = 0;
  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    String profile = 'walking',
  }) async {
    calls++;
    return NavigationRoute(
      coordinates: [origin, destination],
      steps: [
        NavigationStep(
          instruction: 'Walk toward College of Business',
          distanceMeters: 220,
          durationSeconds: 180,
          maneuver: origin,
          maneuverType: 'depart',
        ),
      ],
      distanceMeters: 220,
      durationSeconds: 180,
    );
  }
}
