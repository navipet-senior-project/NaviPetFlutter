import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_models.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.position,
    this.shouldThrowOnGetPosition = false,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission requestedPermission;
  Position? position;
  bool shouldThrowOnGetPosition;
  bool requestPermissionCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalled = true;
    permission = requestedPermission;
    return permission;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (shouldThrowOnGetPosition) {
      throw Exception('Failed to get position');
    }
    if (position == null) {
      throw Exception('No position available');
    }
    return position!;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> openLocationSettings() async {
    throw UnimplementedError();
  }

  @override
  Future<bool> openAppSettings() async {
    throw UnimplementedError();
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    throw UnimplementedError();
  }

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    throw UnimplementedError();
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() {
    throw UnimplementedError();
  }

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('LocationReading value semantics', () {
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
      expect(reading.isApproximate, isTrue);
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
  });

  group('GeolocatorLocationService', () {
    late GeolocatorPlatform originalPlatform;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test(
      'returns serviceDisabled with no coordinate when service is off',
      () async {
        final fake = FakeGeolocatorPlatform(serviceEnabled: false);
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        final reading = await service.current();

        expect(
          reading.availability,
          equals(LocationAvailability.serviceDisabled),
        );
        expect(reading.coordinate, isNull);
        expect(reading.usable, isFalse);
      },
    );

    test(
      'returns permissionDenied with no coordinate when denied after request',
      () async {
        final fake = FakeGeolocatorPlatform(
          permission: LocationPermission.denied,
          requestedPermission: LocationPermission.denied,
        );
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        final reading = await service.current();

        expect(
          reading.availability,
          equals(LocationAvailability.permissionDenied),
        );
        expect(reading.coordinate, isNull);
        expect(reading.usable, isFalse);
        expect(fake.requestPermissionCalled, isTrue);
      },
    );

    test(
      'returns permissionDeniedForever and does not call requestPermission when already denied forever',
      () async {
        final fake = FakeGeolocatorPlatform(
          permission: LocationPermission.deniedForever,
        );
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        final reading = await service.current();

        expect(
          reading.availability,
          equals(LocationAvailability.permissionDeniedForever),
        );
        expect(reading.coordinate, isNull);
        expect(reading.usable, isFalse);
        expect(fake.requestPermissionCalled, isFalse);
      },
    );

    test(
      'returns available with matching coordinate when permission granted and fix obtained',
      () async {
        const testCoord = NavigationCoordinate(
          latitude: 33.784,
          longitude: -118.115,
        );
        final testPosition = Position(
          longitude: testCoord.longitude,
          latitude: testCoord.latitude,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final fake = FakeGeolocatorPlatform(position: testPosition);
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        final reading = await service.current();

        expect(reading.availability, equals(LocationAvailability.available));
        expect(reading.coordinate?.latitude, equals(testCoord.latitude));
        expect(reading.coordinate?.longitude, equals(testCoord.longitude));
        expect(reading.usable, isTrue);
        expect(reading.timestamp, equals(testPosition.timestamp));
      },
    );

    test(
      'returns approximate with remembered coordinate when permission granted but getCurrentPosition throws',
      () async {
        const rememberedCoord = NavigationCoordinate(
          latitude: 33.780,
          longitude: -118.110,
        );
        const testCoord = NavigationCoordinate(
          latitude: 33.784,
          longitude: -118.115,
        );
        final testPosition = Position(
          longitude: testCoord.longitude,
          latitude: testCoord.latitude,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final fake = FakeGeolocatorPlatform(
          position: testPosition,
          shouldThrowOnGetPosition: true,
        );
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService(lastKnown: rememberedCoord);
        final reading = await service.current();

        expect(reading.availability, equals(LocationAvailability.approximate));
        expect(reading.coordinate, equals(rememberedCoord));
        expect(reading.usable, isTrue);
        expect(reading.isApproximate, isTrue);
      },
    );

    test(
      'returns unavailable with no coordinate when permission granted but no remembered position',
      () async {
        const testCoord = NavigationCoordinate(
          latitude: 33.784,
          longitude: -118.115,
        );
        final testPosition = Position(
          longitude: testCoord.longitude,
          latitude: testCoord.latitude,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final fake = FakeGeolocatorPlatform(
          position: testPosition,
          shouldThrowOnGetPosition: true,
        );
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        final reading = await service.current();

        expect(reading.availability, equals(LocationAvailability.unavailable));
        expect(reading.coordinate, isNull);
        expect(reading.usable, isFalse);
      },
    );

    test(
      'guarantees that a remembered position with an error is approximate, never available',
      () async {
        const rememberedCoord = NavigationCoordinate(
          latitude: 33.780,
          longitude: -118.110,
        );
        const testCoord = NavigationCoordinate(
          latitude: 33.784,
          longitude: -118.115,
        );
        final testPosition = Position(
          longitude: testCoord.longitude,
          latitude: testCoord.latitude,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final fake = FakeGeolocatorPlatform(
          position: testPosition,
          shouldThrowOnGetPosition: true,
        );
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService(lastKnown: rememberedCoord);
        final reading = await service.current();

        // Critical assertion: remembered position must never be available
        expect(reading.availability, isNot(LocationAvailability.available));
        expect(reading.availability, equals(LocationAvailability.approximate));
        expect(reading.coordinate, equals(rememberedCoord));
      },
    );

    test(
      'updates _lastKnown when a position is successfully obtained',
      () async {
        const testCoord = NavigationCoordinate(
          latitude: 33.784,
          longitude: -118.115,
        );
        final testPosition = Position(
          longitude: testCoord.longitude,
          latitude: testCoord.latitude,
          timestamp: DateTime(2024, 1, 1),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

        final fake = FakeGeolocatorPlatform(position: testPosition);
        GeolocatorPlatform.instance = fake;

        final service = GeolocatorLocationService();
        await service.current();

        // Now simulate another call without a position available
        fake.shouldThrowOnGetPosition = true;
        final secondReading = await service.current();

        // Should return the remembered coordinate as approximate
        expect(
          secondReading.availability,
          equals(LocationAvailability.approximate),
        );
        expect(secondReading.coordinate?.latitude, equals(testCoord.latitude));
        expect(
          secondReading.coordinate?.longitude,
          equals(testCoord.longitude),
        );
        expect(secondReading.usable, isTrue);
      },
    );
  });
}
