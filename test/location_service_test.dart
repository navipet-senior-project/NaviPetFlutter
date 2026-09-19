import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_models.dart';

void main() {
  test('an available reading is usable', () {
    final reading = LocationReading(
      availability: LocationAvailability.available,
      coordinate: const NavigationCoordinate(
        latitude: 33.784,
        longitude: -118.115,
      ),
      timestamp: DateTime.now(),
    );

    expect(reading.usable, isTrue);
  });

  test('an approximate reading is still usable', () {
    final reading = LocationReading(
      availability: LocationAvailability.approximate,
      coordinate: const NavigationCoordinate(
        latitude: 33.784,
        longitude: -118.115,
      ),
      timestamp: DateTime.now(),
    );

    expect(reading.usable, isTrue);
  });

  test('a denied reading is not usable and carries no coordinate', () {
    const reading = LocationReading(
      availability: LocationAvailability.permissionDenied,
    );

    expect(reading.usable, isFalse);
    expect(reading.coordinate, isNull);
  });

  test('a reading without a coordinate is never usable', () {
    const reading = LocationReading(
      availability: LocationAvailability.available,
    );

    expect(reading.usable, isFalse);
  });
}
