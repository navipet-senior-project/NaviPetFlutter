import 'indoor_ar_contract.dart';
import 'navigation_models.dart';

export 'navigation_models.dart' show CampusDestinationType;

enum CampusSearchFailure { offline, api, unauthorized }

class CampusSearchException implements Exception {
  const CampusSearchException({
    required this.failure,
    required this.message,
    this.statusCode,
    this.code,
  });

  final CampusSearchFailure failure;
  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class CampusPlace {
  const CampusPlace({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.source,
    this.buildingCode,
    this.roomNumber,
    this.floorNumber,
    this.outdoorDestination,
    this.arrivalRadiusMeters,
    this.footprint,
    this.indoorDestinationId,
    this.indoorRequest,
    this.external = false,
    this.attribution,
    this.distanceMeters,
  });

  factory CampusPlace.fromJson(Map<String, dynamic> json) {
    final navigation = json['navigation'];
    final navigationJson = navigation is Map<String, dynamic>
        ? navigation
        : const <String, dynamic>{};
    final outdoor = navigationJson['outdoorDestination'];
    final outdoorJson = outdoor is Map<String, dynamic> ? outdoor : null;
    final latitude = outdoorJson?['latitude'];
    final longitude = outdoorJson?['longitude'];

    final room = _optionalString(json['roomNumber']);

    return CampusPlace(
      id: _requiredString(json, 'id'),
      type: _parseType(_requiredString(json, 'type')),
      title: _requiredString(json, 'title'),
      subtitle: _requiredString(json, 'subtitle'),
      source: _requiredString(json, 'source'),
      buildingCode: _optionalString(json['buildingCode']),
      roomNumber: room,
      floorNumber: _optionalString(json['floorNumber']),
      outdoorDestination: latitude is num && longitude is num
          ? NavigationCoordinate(
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
            )
          : null,
      arrivalRadiusMeters: validArrivalRadiusMeters(
        navigationJson['arrivalRadiusMeters'],
      ),
      footprint: validFootprint(navigationJson['footprint']),
      indoorDestinationId: _optionalString(
        navigationJson['indoorDestinationId'],
      ),
      indoorRequest: room == null
          ? null
          : IndoorArRequest.fromDoorPose(json['indoor'], room: room),
      external: json['external'] == true,
      attribution: _optionalString(json['attribution']),
      distanceMeters: (json['distanceMeters'] as num?)?.round(),
    );
  }

  final String id;
  final CampusDestinationType type;
  final String title;
  final String subtitle;
  final String source;
  final String? buildingCode;
  final String? roomNumber;
  final String? floorNumber;
  final NavigationCoordinate? outdoorDestination;

  /// Per-destination arrival radius from the server; null when absent or
  /// outside 3–50 m, which means the app default applies.
  final int? arrivalRadiusMeters;

  /// Building outline from the server; null when absent or malformed.
  final List<NavigationCoordinate>? footprint;
  final String? indoorDestinationId;
  final IndoorArRequest? indoorRequest;
  final bool external;
  final String? attribution;
  final int? distanceMeters;

  bool get hasIndoorNavigation =>
      indoorDestinationId?.trim().isNotEmpty == true;

  bool get isBuildingAlternative =>
      subtitle.startsWith('Building-level alternative');

  bool get isLocal => !external && source != 'mapbox';

  /// [source] of a place the app suggests on its own (a popular location or
  /// a class building). Its [id] is synthetic, so it must be resolved to a
  /// real campus record before it can be stored as a recent search.
  static const suggestedSource = 'suggested';

  bool get isSuggestion => source == suggestedSource;

  NaviDestination toDestination() {
    final outdoor = outdoorDestination;
    if (outdoor == null) {
      throw const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Verified outdoor navigation is unavailable.',
      );
    }
    return NaviDestination(
      id: id,
      type: type,
      name: title,
      address: subtitle,
      coordinate: outdoor,
      buildingCode: buildingCode,
      roomNumber: roomNumber,
      floorNumber: floorNumber,
      indoorDestinationId: hasIndoorNavigation
          ? indoorDestinationId!.trim()
          : null,
      external: external,
      attribution: attribution,
      isBuildingAlternative: isBuildingAlternative,
      arrivalRadiusMeters: arrivalRadiusMeters,
      footprint: footprint,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _optionalString(json[key]);
    if (value == null) {
      throw CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus search returned an invalid $key.',
      );
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static CampusDestinationType _parseType(String value) {
    return CampusDestinationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus search returned an invalid destination type.',
      ),
    );
  }
}
