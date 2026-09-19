import 'travel_mode.dart';

class NavigationCoordinate {
  const NavigationCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum CampusDestinationType {
  building,
  room,
  entrance,
  parking,
  dining,
  service,
  amenity,
  transit,
  housing,
  landmark,
  external,
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.mapboxId,
    required this.name,
    required this.description,
  });

  final String mapboxId;
  final String name;
  final String description;
}

class NaviDestination {
  const NaviDestination({
    required this.name,
    required this.address,
    required this.coordinate,
    this.id,
    this.type,
    this.buildingCode,
    this.roomNumber,
    this.floorNumber,
    this.indoorDestinationId,
    this.external = false,
    this.attribution,
    this.isBuildingAlternative = false,
  });

  final String name;
  final String address;
  final NavigationCoordinate coordinate;
  final String? id;
  final CampusDestinationType? type;
  final String? buildingCode;
  final String? roomNumber;
  final String? floorNumber;
  final String? indoorDestinationId;
  final bool external;
  final String? attribution;
  final bool isBuildingAlternative;

  bool get hasIndoorNavigation =>
      indoorDestinationId?.trim().isNotEmpty == true;
}

class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuver,
    this.maneuverType,
    this.maneuverModifier,
  });

  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final NavigationCoordinate maneuver;

  /// Mapbox maneuver type, for example `turn`, `depart`, or `arrive`.
  final String? maneuverType;

  /// Mapbox maneuver modifier, for example `left` or `slight right`.
  final String? maneuverModifier;

  String get distanceLabel {
    final feet = distanceMeters * 3.28084;
    if (feet < 1000) return '${feet.round()} ft';
    return '${(distanceMeters / 1609.344).toStringAsFixed(1)} mi';
  }
}

class NavigationRoute {
  const NavigationRoute({
    required this.coordinates,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<NavigationCoordinate> coordinates;
  final List<NavigationStep> steps;
  final double distanceMeters;
  final double durationSeconds;

  String get distanceLabel {
    final miles = distanceMeters / 1609.344;
    if (miles < 0.1) return '${(distanceMeters * 3.28084).round()} ft';
    return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
}

class NavigationTripSummary {
  const NavigationTripSummary({
    required this.elapsed,
    required this.walkingSteps,
  });

  final Duration elapsed;
  final int? walkingSteps;

  String get walkingStepsLabel => walkingSteps?.toString() ?? 'Unavailable';

  String get elapsedLabel {
    final totalSeconds = elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

/// One routing answer, plus room for the alternates the backend cannot
/// produce yet. [routes] holds a single entry today.
class RoutePlan {
  const RoutePlan({
    required this.routes,
    required this.mode,
    this.selectedIndex = 0,
    this.warnings = const [],
    this.endsAtBuilding = false,
  });

  final List<NavigationRoute> routes;
  final TravelMode mode;
  final int selectedIndex;
  final List<String> warnings;

  /// True when guidance stops at a building rather than the exact place the
  /// user asked for — for example a room whose pin resolves to its building.
  final bool endsAtBuilding;

  NavigationRoute get selected => routes[selectedIndex];

  bool get hasAlternatives => routes.length > 1;

  RoutePlan select(int index) => RoutePlan(
    routes: routes,
    mode: mode,
    selectedIndex: index.clamp(0, routes.length - 1),
    warnings: warnings,
    endsAtBuilding: endsAtBuilding,
  );
}
