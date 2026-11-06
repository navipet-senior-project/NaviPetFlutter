import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/destination_presence.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/osm_test_footprints.dart';

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
  test(
    'OpenStreetMap College of Business courtyard is outside the footprint',
    () {
      final footprint = osmTestFootprint('College of Business');
      final rings = footprintToGeoJson(footprint)['coordinates'] as List;
      expect(rings, hasLength(2));
      expect(rings[0], hasLength(17));
      expect(rings[1], hasLength(5));
      final hole = footprint.polygons.single[1];
      final unique = hole.take(hole.length - 1).toList();
      final courtyard = NavigationCoordinate(
        latitude:
            unique.map((point) => point.latitude).reduce((a, b) => a + b) /
            unique.length,
        longitude:
            unique.map((point) => point.longitude).reduce((a, b) => a + b) /
            unique.length,
      );
      // Same entry margin as a 5 m fix in DestinationPresenceTracker.
      const fixAccuracyMeters = 5.0;
      final entryMargin =
          math.max(fixAccuracyMeters, ArrivalPolicy.boundaryHysteresisMeters) +
          ArrivalPolicy.boundaryHysteresisMeters;
      expect(signedFootprintDistanceMeters(footprint, courtyard), lessThan(0));
      expect(
        signedFootprintDistanceMeters(footprint, insideCollegeOfBusiness),
        greaterThan(entryMargin),
      );
      final pinGap = signedFootprintDistanceMeters(
        footprint,
        collegeOfBusinessOutdoor,
      );
      expect(pinGap, greaterThan(0));
      expect(pinGap, lessThan(entryMargin));
      expect(
        signedFootprintDistanceMeters(footprint, hornCenterOutdoor),
        lessThan(0),
      );
      expect(
        signedFootprintDistanceMeters(
          osmTestFootprint('Steve and Nini Horn Center'),
          hornCenterOutdoor,
        ),
        greaterThan(0),
      );
    },
  );
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
