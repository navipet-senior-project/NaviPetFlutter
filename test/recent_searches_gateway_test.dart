import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/recent_searches_gateway.dart';
import 'package:navipet/data/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const horn = CampusPlace(
  id: 'c498dd9f-18ab-49be-84aa-50a0d8c9117b',
  type: CampusDestinationType.building,
  title: 'Horn Center',
  subtitle: 'HC',
  source: 'csulb',
  buildingCode: 'HC',
  outdoorDestination: NavigationCoordinate(
    latitude: 33.78307046,
    longitude: -118.11456126,
  ),
);

class FakeRemote implements RecentSearchesGateway {
  List<CampusPlace> remote = const [];
  Object? error;
  final List<String> saved = [];
  int clears = 0;
  Completer<void>? listGate;
  Completer<void>? saveGate;

  @override
  Future<List<CampusPlace>> list() async {
    await listGate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return remote;
  }

  @override
  Future<void> save(CampusPlace place) async {
    await saveGate?.future;
    final failure = error;
    if (failure != null) throw failure;
    saved.add(place.id);
  }

  @override
  Future<void> clear() async {
    final failure = error;
    if (failure != null) throw failure;
    clears++;
  }

  @override
  Future<void> clearLocal() async {}
}

class FakeAuth implements AuthTokenProvider {
  FakeAuth(this.tokens);
  final List<String?> tokens;
  final List<bool> refreshCalls = [];
  int _index = 0;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshCalls.add(forceRefresh);
    final value = tokens[_index.clamp(0, tokens.length - 1)];
    _index++;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('serves the remote list and caches it', () async {
    final remote = FakeRemote()..remote = const [horn];
    final store = SearchHistoryStore();
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    final result = await gateway.list();

    expect(result.single.id, horn.id);
    expect((await store.load()).single.name, 'Horn Center');
  });

  test('falls back to the cache when the remote fails', () async {
    final store = SearchHistoryStore();
    await store.add(horn.toDestination());
    final remote = FakeRemote()..error = Exception('offline');
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    final result = await gateway.list();

    expect(result.single.title, 'Horn Center');
  });

  test('saving writes through to the remote and the cache', () async {
    final remote = FakeRemote();
    final store = SearchHistoryStore();
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    await gateway.save(horn);

    expect(remote.saved, [horn.id]);
    expect((await store.load()).single.id, horn.id);
  });

  test('a remote save failure still caches locally', () async {
    final remote = FakeRemote()..error = Exception('offline');
    final store = SearchHistoryStore();
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    await gateway.save(horn);

    expect((await store.load()).single.id, horn.id);
  });

  test(
    'an external place already in the cache never reaches the UI on fallback',
    () async {
      final store = SearchHistoryStore();
      await store.add(
        const NaviDestination(
          id: 'ext-1',
          name: 'Off-map Coffee',
          address: 'Somewhere nearby',
          coordinate: NavigationCoordinate(
            latitude: 33.7838,
            longitude: -118.1141,
          ),
          external: true,
        ),
      );
      final remote = FakeRemote()..error = Exception('offline');
      final gateway = CachedRecentSearches(remote: remote, cache: store);

      final result = await gateway.list();

      expect(result, isEmpty);
    },
  );

  test(
    'saving an external place never caches it locally, even if the remote save fails',
    () async {
      const externalPlace = CampusPlace(
        id: 'ext-2',
        type: CampusDestinationType.external,
        title: 'Off-map POI',
        subtitle: 'Nearby',
        source: 'mapbox',
        external: true,
        outdoorDestination: NavigationCoordinate(
          latitude: 33.7838,
          longitude: -118.1141,
        ),
      );
      final remote = FakeRemote()..error = Exception('offline');
      final store = SearchHistoryStore();
      final gateway = CachedRecentSearches(remote: remote, cache: store);

      await gateway.save(externalPlace);

      expect(await store.load(), isEmpty);
    },
  );

  test('clear removes both the remote and local history', () async {
    final remote = FakeRemote();
    final store = SearchHistoryStore();
    await store.add(horn.toDestination());
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    await gateway.clear();

    expect(remote.clears, 1);
    expect(await store.load(), isEmpty);
  });

  test('a remote clear failure still clears the local history', () async {
    final remote = FakeRemote()..error = Exception('offline');
    final store = SearchHistoryStore();
    await store.add(horn.toDestination());
    final gateway = CachedRecentSearches(remote: remote, cache: store);

    await gateway.clear();

    expect(remote.clears, 0);
    expect(await store.load(), isEmpty);
  });

  test(
    'clearLocal removes the cache without clearing remote history',
    () async {
      final remote = FakeRemote();
      final store = SearchHistoryStore();
      await store.add(horn.toDestination());
      final gateway = CachedRecentSearches(remote: remote, cache: store);

      await gateway.clearLocal();

      expect(remote.clears, 0);
      expect(await store.load(), isEmpty);
    },
  );

  test(
    'clearLocal prevents an older in-flight save from restoring the cache',
    () async {
      final remote = FakeRemote()..saveGate = Completer<void>();
      final store = SearchHistoryStore();
      final gateway = CachedRecentSearches(remote: remote, cache: store);

      final pendingSave = gateway.save(horn);
      await Future<void>.delayed(Duration.zero);
      await gateway.clearLocal();
      remote.saveGate!.complete();
      await pendingSave;

      expect(await store.load(), isEmpty);
    },
  );

  test(
    'clearLocal prevents an older in-flight list from restoring the cache',
    () async {
      final remote = FakeRemote()
        ..remote = const [horn]
        ..listGate = Completer<void>();
      final store = SearchHistoryStore();
      final gateway = CachedRecentSearches(remote: remote, cache: store);

      final pendingList = gateway.list();
      await Future<void>.delayed(Duration.zero);
      await gateway.clearLocal();
      remote.listGate!.complete();
      await pendingList;

      expect(await store.load(), isEmpty);
    },
  );

  test(
    'HttpRecentSearchesGateway refreshes once and retries after a 401',
    () async {
      var calls = 0;
      final auth = FakeAuth(['stale', 'fresh']);
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '{"error":{"code":"INVALID_ACCESS_TOKEN","message":"Authentication required"}}',
            401,
          );
        }
        return http.Response('{"results":[]}', 200);
      });
      final gateway = HttpRecentSearchesGateway(
        baseUrl: 'https://api.test',
        auth: auth,
        client: client,
      );

      await gateway.list();

      expect(calls, 2);
      expect(auth.refreshCalls, [false, true]);
    },
  );

  test(
    'HttpRecentSearchesGateway reports unauthorized when the retry also fails',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          '{"error":{"code":"INVALID_ACCESS_TOKEN","message":"Authentication required"}}',
          401,
        ),
      );
      final gateway = HttpRecentSearchesGateway(
        baseUrl: 'https://api.test',
        auth: FakeAuth(['stale', 'also-stale']),
        client: client,
      );

      await expectLater(
        gateway.list(),
        throwsA(
          isA<CampusSearchException>().having(
            (error) => error.failure,
            'failure',
            CampusSearchFailure.unauthorized,
          ),
        ),
      );
    },
  );
}
