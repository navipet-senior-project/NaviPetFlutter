import 'package:flutter_test/flutter_test.dart';
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

  @override
  Future<List<CampusPlace>> list() async {
    final failure = error;
    if (failure != null) throw failure;
    return remote;
  }

  @override
  Future<void> save(CampusPlace place) async {
    final failure = error;
    if (failure != null) throw failure;
    saved.add(place.id);
  }

  @override
  Future<void> clear() async {
    clears++;
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
}
