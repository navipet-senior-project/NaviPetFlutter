import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';

void main() {
  test('parses room metadata and converts only the verified outdoor point', () {
    final place = CampusPlace.fromJson({
      'id': '00000000-0000-4000-8000-000000000001',
      'type': 'room',
      'title': 'COB 140',
      'subtitle': 'College of Business · Floor 1',
      'source': 'csulb',
      'buildingCode': 'COB',
      'roomNumber': '140',
      'floorNumber': '1',
      'navigation': {
        'arrivalRadiusMeters': 18,
        'outdoorDestination': {'latitude': 33.7832, 'longitude': -118.1147},
        'indoorDestinationId': 'multiset-cob-140',
      },
    });

    expect(place.type, CampusDestinationType.room);
    expect(place.hasIndoorNavigation, isTrue);
    expect(place.toDestination().coordinate.latitude, 33.7832);
    expect(place.toDestination().coordinate.longitude, -118.1147);
    expect(place.arrivalRadiusMeters, 18);
    expect(place.toDestination().arrivalRadiusMeters, 18);
  });

  test('recognizes housing, external, and building-alternative results', () {
    final housing = CampusPlace.fromJson({
      'id': '00000000-0000-4000-8000-000000000002',
      'type': 'housing',
      'title': 'Parkside North',
      'subtitle': 'PN',
      'source': 'csulb',
    });
    final external = CampusPlace.fromJson({
      'id': 'mapbox.place.1',
      'type': 'external',
      'title': 'Long Beach',
      'subtitle': 'California',
      'source': 'mapbox',
      'external': true,
    });
    final alternative = CampusPlace.fromJson({
      'id': '00000000-0000-4000-8000-000000000003',
      'type': 'building',
      'title': 'College of Business',
      'subtitle': 'Building-level alternative · COB',
      'source': 'csulb',
    });

    expect(housing.type, CampusDestinationType.housing);
    expect(external.type, CampusDestinationType.external);
    expect(external.external, isTrue);
    expect(alternative.isBuildingAlternative, isTrue);
  });

  test('rejects conversion when verified outdoor coordinates are absent', () {
    final place = CampusPlace.fromJson({
      'id': '00000000-0000-4000-8000-000000000004',
      'type': 'building',
      'title': 'Library',
      'subtitle': 'LIB',
      'source': 'csulb',
    });

    expect(
      place.toDestination,
      throwsA(
        isA<CampusSearchException>().having(
          (error) => error.failure,
          'failure',
          CampusSearchFailure.api,
        ),
      ),
    );
  });

  group('arrival radius', () {
    Map<String, dynamic> json(Object? radius, {bool include = true}) => {
      'id': '00000000-0000-4000-8000-000000000004',
      'type': 'building',
      'title': 'Horn Center',
      'subtitle': 'HC',
      'source': 'csulb',
      'navigation': {
        'outdoorDestination': {'latitude': 33.7831, 'longitude': -118.1146},
        if (include) 'arrivalRadiusMeters': radius,
      },
    };

    test('reads the server radius into the destination', () {
      final place = CampusPlace.fromJson(json(25));
      expect(place.arrivalRadiusMeters, 25);
      expect(place.toDestination().arrivalRadiusMeters, 25);
      expect(place.toDestination().arrivalRadius, 25);
    });

    test('accepts the 3 and 50 boundaries', () {
      expect(CampusPlace.fromJson(json(3)).arrivalRadiusMeters, 3);
      expect(CampusPlace.fromJson(json(50)).arrivalRadiusMeters, 50);
    });

    test('missing field falls back to the 10 m default', () {
      final place = CampusPlace.fromJson(json(null, include: false));
      expect(place.arrivalRadiusMeters, isNull);
      expect(place.toDestination().arrivalRadius, 10);
    });

    test('out-of-range or malformed values fall back to 10 m', () {
      for (final bad in [2, 51, 0, -1, 25.5, '25', true, null]) {
        final place = CampusPlace.fromJson(json(bad));
        expect(place.arrivalRadiusMeters, isNull, reason: '$bad');
        expect(place.toDestination().arrivalRadius, 10, reason: '$bad');
      }
    });
  });
}
