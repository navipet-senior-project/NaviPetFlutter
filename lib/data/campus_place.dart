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
    this.indoorDestinationId,
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

    return CampusPlace(
      id: _requiredString(json, 'id'),
      type: _parseType(_requiredString(json, 'type')),
      title: _requiredString(json, 'title'),
      subtitle: _requiredString(json, 'subtitle'),
      source: _requiredString(json, 'source'),
      buildingCode: _optionalString(json['buildingCode']),
      roomNumber: _optionalString(json['roomNumber']),
      floorNumber: _optionalString(json['floorNumber']),
      outdoorDestination: latitude is num && longitude is num
          ? NavigationCoordinate(
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
            )
          : null,
      indoorDestinationId: _optionalString(
        navigationJson['indoorDestinationId'],
      ),
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
  final String? indoorDestinationId;
  final bool external;
  final String? attribution;
  final int? distanceMeters;

  bool get hasIndoorNavigation =>
      indoorDestinationId?.trim().isNotEmpty == true;

  bool get isBuildingAlternative =>
      subtitle.startsWith('Building-level alternative');

  bool get isLocal => !external && source != 'mapbox';

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
