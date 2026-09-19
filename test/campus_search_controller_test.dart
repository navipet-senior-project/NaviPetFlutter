import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/campus_search_controller.dart';
import 'package:navipet/data/campus_search_gateway.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/search_location_provider.dart';

const cob = CampusPlace(
  id: '00000000-0000-4000-8000-000000000001',
  type: CampusDestinationType.building,
  title: 'College of Business',
  subtitle: 'COB',
  source: 'csulb',
  buildingCode: 'COB',
  outdoorDestination: NavigationCoordinate(
    latitude: 33.7832,
    longitude: -118.1147,
  ),
);

class FakeGateway implements CampusSearchGateway {
  final List<String> queries = [];
  final List<NavigationCoordinate?> proximities = [];
  Future<List<CampusPlace>> Function(String query)? onAutocomplete;
  Future<CampusPlace> Function(String id)? onPlace;

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) {
    queries.add(query);
    proximities.add(proximity);
    return onAutocomplete?.call(query) ?? Future.value([cob]);
  }

  @override
  Future<CampusPlace> place(String stableId) =>
      onPlace?.call(stableId) ?? Future.value(cob);
}

class FakeLocationProvider implements SearchLocationProvider {
  FakeLocationProvider([
    this.result = const SearchLocationResult.notRequired(),
  ]);

  SearchLocationResult result;
  final List<String> queries = [];

  @override
  Future<SearchLocationResult> locationFor(String normalizedQuery) async {
    queries.add(normalizedQuery);
    return result;
  }
}

Future<void> debounceElapsed() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('shows loading without querying for a one-character input', () async {
    final gateway = FakeGateway();
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('');
    await debounceElapsed();
    expect(gateway.queries, isEmpty);

    controller.queryChanged('C');
    expect(controller.status, CampusSearchStatus.loading);
    await debounceElapsed();

    expect(gateway.queries, isEmpty);
    expect(controller.status, CampusSearchStatus.loading);
  });

  test('does not retry a one-character query', () async {
    final gateway = FakeGateway();
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('C');
    await controller.retry();

    expect(gateway.queries, isEmpty);
  });

  test('shows loading while the active request is unresolved', () async {
    final pending = Completer<List<CampusPlace>>();
    final gateway = FakeGateway()..onAutocomplete = (_) => pending.future;
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('CO');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.loading);

    pending.complete([cob]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, CampusSearchStatus.results);
  });

  test('ignores stale responses and a completion after query clear', () async {
    final first = Completer<List<CampusPlace>>();
    final second = Completer<List<CampusPlace>>();
    final gateway = FakeGateway()
      ..onAutocomplete = (query) =>
          query == 'CO' ? first.future : second.future;
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('CO');
    await debounceElapsed();
    controller.queryChanged('COB');
    await debounceElapsed();
    second.complete([cob]);
    await Future<void>.delayed(Duration.zero);
    first.complete(const []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.results, [cob]);
    expect(controller.status, CampusSearchStatus.results);

    final third = Completer<List<CampusPlace>>();
    gateway.onAutocomplete = (_) => third.future;
    controller.queryChanged('LIB');
    await debounceElapsed();
    controller.queryChanged('');
    third.complete([cob]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, CampusSearchStatus.initial);
    expect(controller.results, isEmpty);
  });

  test('maps empty, offline, and API responses to explicit states', () async {
    final gateway = FakeGateway();
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    gateway.onAutocomplete = (_) async => const [];
    controller.queryChanged('CO');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.noResults);

    gateway.onAutocomplete = (_) => Future.error(
      const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'offline',
      ),
    );
    controller.queryChanged('COB');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.offline);

    gateway.onAutocomplete = (_) => Future.error(
      const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'bad gateway',
      ),
    );
    controller.queryChanged('HSCI');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.apiError);
  });

  test('maps proximity permission and unavailable location states', () async {
    final gateway = FakeGateway();
    final location = FakeLocationProvider(
      const SearchLocationResult.permissionRequired(),
    );
    final controller = CampusSearchController(
      gateway: gateway,
      location: location,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('nearest parking');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.permissionRequired);
    expect(gateway.queries, isEmpty);

    location.result = const SearchLocationResult.unavailable();
    controller.queryChanged('coffee near me');
    await debounceElapsed();
    expect(controller.status, CampusSearchStatus.locationUnavailable);
  });

  test('sends paired coordinates only for exact proximity intent', () async {
    final gateway = FakeGateway();
    final location = FakeLocationProvider(
      const SearchLocationResult.available(
        NavigationCoordinate(latitude: 33.7838, longitude: -118.1141),
      ),
    );
    final controller = CampusSearchController(
      gateway: gateway,
      location: location,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('COB');
    await debounceElapsed();
    expect(location.queries, isEmpty);
    expect(gateway.proximities.single, isNull);

    controller.queryChanged('nearest parking');
    await debounceElapsed();
    expect(location.queries, ['nearest parking']);
    expect(gateway.proximities.last?.latitude, 33.7838);
    expect(gateway.proximities.last?.longitude, -118.1141);
  });

  test('filters external results out of autocomplete', () async {
    final gateway = FakeGateway()
      ..onAutocomplete = (_) async => [
        cob,
        const CampusPlace(
          id: 'mapbox:dXJuOm1ieHBsYzpBQQ',
          type: CampusDestinationType.external,
          title: 'College of Business',
          subtitle: 'Somewhere else entirely',
          source: 'mapbox',
          external: true,
          outdoorDestination: NavigationCoordinate(
            latitude: 34.0522,
            longitude: -118.2437,
          ),
        ),
      ];
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('college of business');
    await debounceElapsed();

    expect(controller.results.map((item) => item.id), [cob.id]);
    expect(controller.status, CampusSearchStatus.results);
  });

  test('reports no results when every match was off campus', () async {
    final gateway = FakeGateway()
      ..onAutocomplete = (_) async => [
        const CampusPlace(
          id: 'mapbox:dXJuOm1ieHBsYzpCQg',
          type: CampusDestinationType.external,
          title: 'Vons',
          subtitle: 'Bellflower Blvd',
          source: 'mapbox',
          external: true,
        ),
      ];
    final controller = CampusSearchController(
      gateway: gateway,
      location: FakeLocationProvider(),
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('vons');
    await debounceElapsed();

    expect(controller.results, isEmpty);
    expect(controller.status, CampusSearchStatus.noResults);
  });
}
