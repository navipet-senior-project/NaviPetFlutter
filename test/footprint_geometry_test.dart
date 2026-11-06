import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const outer = [
  [0, 0],
  [0.001, 0],
  [0.001, 0.001],
  [0, 0.001],
  [0, 0],
];
const hole = [
  [0.0004, 0.0004],
  [0.0006, 0.0004],
  [0.0006, 0.0006],
  [0.0004, 0.0006],
  [0.0004, 0.0004],
];

void main() {
  test('preserves holes through parsing and cache encoding', () {
    final geometry = {
      'type': 'Polygon',
      'coordinates': [outer, hole],
    };
    expect(footprintToGeoJson(validFootprint(geometry)!), geometry);
  });
  test('preserves all MultiPolygon components', () {
    final geometry = {
      'type': 'MultiPolygon',
      'coordinates': [
        [outer, hole],
        [outer],
      ],
    };
    expect(validFootprint(geometry), isNotNull);
    expect(footprintToGeoJson(validFootprint(geometry)!), geometry);
  });
  test('rejects non-finite coordinates', () {
    expect(
      validFootprint({
        'type': 'Polygon',
        'coordinates': [
          [
            [double.nan, 0],
            [1, 0],
            [1, 1],
            [double.nan, 0],
          ],
        ],
      }),
      isNull,
    );
  });
  test('multipart containment, hole, edge and vertex have correct signs', () {
    final second = [
      for (final point in outer) [point[0] + 0.003, point[1]],
    ];
    final geometry = validFootprint({
      'type': 'MultiPolygon',
      'coordinates': [
        [outer, hole],
        [second],
      ],
    })!;
    double gap(double latitude, double longitude) =>
        signedFootprintDistanceMeters(
          geometry,
          NavigationCoordinate(latitude: latitude, longitude: longitude),
        );
    expect(gap(0.0002, 0.0002), greaterThan(0));
    expect(gap(0.0002, 0.0032), greaterThan(0));
    expect(gap(0.0005, 0.0005), lessThan(0));
    expect(gap(0.0005, 0.002), lessThan(0));
    expect(gap(0, 0.0005).abs(), lessThan(0.001));
    expect(gap(0, 0).abs(), lessThan(0.001));
  });
  test('single-part MultiPolygon and entrance survive recents cache', () async {
    SharedPreferences.setMockInitialValues({});
    final raw = {
      'type': 'MultiPolygon',
      'coordinates': [
        [outer, hole],
      ],
    };
    final place = CampusPlace.fromJson(
      {
        'id': 'mock',
        'type': 'building',
        'title': 'Mock building',
        'subtitle': 'Mock',
        'source': 'cache',
        'navigation': {
          'outdoorDestination': {'latitude': 0.0002, 'longitude': 0.0002},
          'footprint': raw,
          'entrance': {'latitude': 0, 'longitude': 0.0002},
        },
      }..['subtitle'] = 'Mock',
    );
    final store = SearchHistoryStore();
    await store.add(place.toDestination());
    final [restored] = await store.load();
    expect(footprintToGeoJson(restored.footprint!), raw);
    expect(restored.entranceCoordinate!.latitude, 0);
    expect(restored.coordinate.latitude, 0.0002);
  });
}
