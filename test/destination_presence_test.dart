import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/destination_presence.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/route_progress.dart';

final now = DateTime.utc(2026, 11, 5, 12);
final footprint = validFootprint({
  'type': 'Polygon',
  'coordinates': [
    [
      [0, 0],
      [0.002, 0],
      [0.002, 0.002],
      [0, 0.002],
      [0, 0],
    ],
    [
      [0.0008, 0.0008],
      [0.0012, 0.0008],
      [0.0012, 0.0012],
      [0.0008, 0.0012],
      [0.0008, 0.0008],
    ],
  ],
})!;
LocationReading fix(
  double latitude,
  double longitude, {
  int age = 0,
  double accuracy = 5,
}) => LocationReading(
  availability: LocationAvailability.available,
  coordinate: NavigationCoordinate(latitude: latitude, longitude: longitude),
  timestamp: now.subtract(Duration(seconds: age)),
  accuracyMeters: accuracy,
);

void main() {
  test('two distinct fresh fixes confirm inside, never one or replay', () {
    final presence = DestinationPresenceTracker();
    expect(
      presence.add(footprint, fix(0.0004, 0.0004, age: 1), now),
      DestinationPresence.uncertain,
    );
    expect(
      presence.add(footprint, fix(0.0004, 0.0004, age: 1), now),
      DestinationPresence.uncertain,
    );
    expect(
      presence.add(footprint, fix(0.0004, 0.0004), now),
      DestinationPresence.inside,
    );
  });
  test('holes are outside, walls and accuracy overlaps uncertain', () {
    expect(
      signedFootprintDistanceMeters(footprint, fix(0.001, 0.001).coordinate!),
      lessThan(0),
    );
    final presence = DestinationPresenceTracker();
    presence.add(footprint, fix(0.001, 0.001, age: 1), now);
    expect(
      presence.add(footprint, fix(0.001, 0.001), now),
      DestinationPresence.outside,
    );
    expect(
      presence.add(
        footprint,
        fix(0, 0.001),
        now.add(const Duration(seconds: 1)),
      ),
      DestinationPresence.uncertain,
    );
    expect(
      DestinationPresenceTracker().add(footprint, fix(0.00001, 0.001), now),
      DestinationPresence.uncertain,
    );
  });
  test('stale inaccurate missing or future metadata never confirm arrival', () {
    for (final reading in [
      fix(0.0004, 0.0004, age: 11),
      fix(0.0004, 0.0004, accuracy: 21),
      fix(0.0004, 0.0004, accuracy: -1),
      fix(0.0004, 0.0004, age: -1),
      const LocationReading(
        availability: LocationAvailability.approximate,
        coordinate: NavigationCoordinate(latitude: 0.0004, longitude: 0.0004),
      ),
    ]) {
      final presence = DestinationPresenceTracker();
      presence.add(footprint, reading, now);
      expect(
        presence.add(footprint, reading, now),
        DestinationPresence.uncertain,
      );
    }
  });
  test('outside and uncertain fixes interrupt inside streak', () {
    final presence = DestinationPresenceTracker();
    presence.add(footprint, fix(0.0004, 0.0004, age: 2), now);
    presence.add(footprint, fix(0.003, 0.003, age: 1), now);
    expect(
      presence.add(footprint, fix(0.0004, 0.0004), now),
      DestinationPresence.uncertain,
    );
    expect(
      presence.add(null, fix(0.0004, 0.0004), now),
      DestinationPresence.uncertain,
    );
  });
  test(
    'confirmation expires and hysteresis does not turn a wall into arrival',
    () {
      final presence = DestinationPresenceTracker();
      presence.add(footprint, fix(0.0004, 0.0004, age: 1), now);
      expect(
        presence.add(footprint, fix(0.0004, 0.0004), now),
        DestinationPresence.inside,
      );
      expect(
        presence.valueAt(now.add(const Duration(seconds: 11))),
        DestinationPresence.uncertain,
      );
    },
  );
  test('out-of-order contradictory fix cannot reuse confirmed inside', () {
    final presence = DestinationPresenceTracker();
    presence.add(footprint, fix(0.0004, 0.0004, age: 1), now);
    presence.add(footprint, fix(0.0004, 0.0004), now);
    expect(
      presence.add(footprint, fix(0.003, 0.003, age: 1), now),
      DestinationPresence.uncertain,
    );
  });
}
