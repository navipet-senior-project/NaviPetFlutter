import 'package:geolocator/geolocator.dart';

import 'navigation_models.dart';

enum LocationAvailability {
  available,
  approximate,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
}

class LocationReading {
  const LocationReading({
    required this.availability,
    this.coordinate,
    this.timestamp,
  });

  final LocationAvailability availability;
  final NavigationCoordinate? coordinate;
  final DateTime? timestamp;

  /// True when this reading can be used as a route origin.
  bool get usable =>
      coordinate != null &&
      (availability == LocationAvailability.available ||
          availability == LocationAvailability.approximate);

  bool get isApproximate => availability == LocationAvailability.approximate;
}

abstract interface class LocationService {
  Future<LocationReading> current();

  Stream<NavigationCoordinate> watch();
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({NavigationCoordinate? lastKnown})
    : // An initializing formal would force the private field name into the
      // public constructor signature, making it unusable from other libraries.
      // ignore: prefer_initializing_formals
      _lastKnown = lastKnown;

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 5,
  );

  NavigationCoordinate? _lastKnown;

  @override
  Future<LocationReading> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _fallback(LocationAvailability.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return _fallback(LocationAvailability.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      return _fallback(LocationAvailability.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
      final coordinate = _coordinateFrom(position);
      _lastKnown = coordinate;
      return LocationReading(
        availability: LocationAvailability.available,
        coordinate: coordinate,
        timestamp: position.timestamp,
      );
    } on Object {
      return _fallback(LocationAvailability.unavailable);
    }
  }

  @override
  Stream<NavigationCoordinate> watch() {
    return Geolocator.getPositionStream(locationSettings: _settings).map((
      position,
    ) {
      final coordinate = _coordinateFrom(position);
      _lastKnown = coordinate;
      return coordinate;
    });
  }

  NavigationCoordinate _coordinateFrom(Position position) {
    return NavigationCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// A remembered position is offered as approximate rather than presented as
  /// the user's live location. NaviPet never routes from the campus centre
  /// while pretending that is where the user stands.
  LocationReading _fallback(LocationAvailability availability) {
    final remembered = _lastKnown;
    if (remembered == null) {
      return LocationReading(availability: availability);
    }
    return LocationReading(
      availability: LocationAvailability.approximate,
      coordinate: remembered,
    );
  }
}
