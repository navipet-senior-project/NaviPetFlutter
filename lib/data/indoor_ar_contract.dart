import 'dart:convert';

/// Bridge contract v1 between the app and the Unity AR runtime.
///
/// Every pose is in the MultiSet MapSet frame (left-handed, +Y up, metres,
/// origin at the Floor 1 2 map root), the same frame as the backend's door
/// points. Nothing on either side of the bridge converts.
class IndoorArVector3 {
  const IndoorArVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'z': z};
}

/// One AR session's destination: a single door.
class IndoorArRequest {
  IndoorArRequest({
    required this.room,
    required this.doorKey,
    required this.floor,
    required this.position,
    required this.headingDeg,
    required this.mapCode,
    required this.frame,
  }) {
    if (doorKey.isEmpty || floor.isEmpty || mapCode.isEmpty) {
      throw ArgumentError('doorKey, floor and mapCode must not be empty');
    }
    if (!(position.x.isFinite && position.y.isFinite && position.z.isFinite)) {
      throw ArgumentError.value(position, 'position', 'must be finite');
    }
    // Written as a negated range check so NaN is rejected too.
    if (!(headingDeg >= 0 && headingDeg < 360)) {
      throw ArgumentError.value(
        headingDeg,
        'headingDeg',
        'must be in [0, 360)',
      );
    }
  }

  /// Builds a request from the `indoor` door pose on `/places/:placeId`.
  /// Null when the pose is missing or fails this class's validation.
  static IndoorArRequest? fromDoorPose(Object? json, {required String room}) {
    if (json is! Map<String, dynamic>) return null;
    final position = json['position'];
    if (position is! Map<String, dynamic>) return null;
    final (x, y, z) = (position['x'], position['y'], position['z']);
    final heading = json['headingDeg'];
    final (doorKey, floor) = (json['doorKey'], json['floor']);
    final (mapCode, frame) = (json['mapCode'], json['frame']);
    if (x is! num || y is! num || z is! num || heading is! num) return null;
    if (doorKey is! String || floor is! String) return null;
    if (mapCode is! String || frame is! String) return null;
    final headingDeg = ((heading.toDouble() % 360) + 360) % 360;
    try {
      return IndoorArRequest(
        room: room,
        doorKey: doorKey,
        floor: floor,
        position: IndoorArVector3(x.toDouble(), y.toDouble(), z.toDouble()),
        headingDeg: headingDeg,
        mapCode: mapCode,
        frame: frame,
      );
    } on ArgumentError {
      return null;
    }
  }

  static const schemaVersion = 1;

  final String room;
  final String doorKey;
  final String floor;
  final IndoorArVector3 position;
  final double headingDeg;
  final String mapCode;
  final String frame;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'room': room,
    'doorKey': doorKey,
    'floor': floor,
    'position': position.toJson(),
    'headingDeg': headingDeg,
    'mapCode': mapCode,
    'frame': frame,
  };
}

enum IndoorArStatus {
  arrived,
  cancelled,
  localizationFailed,
  unavailable,
  error,
}

class IndoorArResult {
  const IndoorArResult({
    required this.status,
    required this.localizationQueries,
    required this.durationMs,
    this.checkDistanceM,
    this.confidence,
    this.localizedMapCode,
    this.errorCode,
  });

  /// The build has no Unity library, or the platform has no AR runtime.
  const IndoorArResult.unavailable()
    : this(
        status: IndoorArStatus.unavailable,
        localizationQueries: 0,
        durationMs: 0,
      );

  /// The other side broke the contract.
  const IndoorArResult.badResult()
    : this(
        status: IndoorArStatus.error,
        localizationQueries: 0,
        durationMs: 0,
        errorCode: badResultCode,
      );

  static const badResultCode = 'BAD_RESULT';

  final IndoorArStatus status;

  /// Horizontal distance from the phone to the door point, `arrived` only.
  final double? checkDistanceM;
  final double? confidence;
  final String? localizedMapCode;
  final int localizationQueries;
  final int durationMs;

  /// Set for `error` only.
  final String? errorCode;

  /// Decodes the JSON string the Android host returns. Never throws: anything
  /// that breaks the contract becomes `error` / `BAD_RESULT`, so a bad Unity
  /// build cannot crash the app.
  static IndoorArResult decode(String raw) {
    try {
      return _decode(jsonDecode(raw));
    } on FormatException {
      return const IndoorArResult.badResult();
    }
  }

  static IndoorArResult _decode(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('result is not a JSON object');
    }
    final status =
        IndoorArStatus.values.asNameMap()[json['status']] ??
        (throw const FormatException('unknown status'));
    final distance = _optionalDouble(json['checkDistanceM']);
    final errorCode = _optionalString(json['errorCode']);
    if (status == IndoorArStatus.arrived &&
        (distance == null || distance < 0)) {
      throw const FormatException('arrived needs checkDistanceM >= 0');
    }
    if (status == IndoorArStatus.error &&
        (errorCode == null || errorCode.isEmpty)) {
      throw const FormatException('error needs an errorCode');
    }
    return IndoorArResult(
      status: status,
      localizationQueries: _count(json['localizationQueries']),
      durationMs: _count(json['durationMs']),
      checkDistanceM: status == IndoorArStatus.arrived ? distance : null,
      confidence: _optionalDouble(json['confidence']),
      localizedMapCode: _optionalString(json['localizedMapCode']),
      errorCode: status == IndoorArStatus.error ? errorCode : null,
    );
  }

  static int _count(Object? value) => value is int && value >= 0
      ? value
      : throw const FormatException('expected a non-negative integer');

  static double? _optionalDouble(Object? value) => switch (value) {
    null => null,
    final num number when number.isFinite => number.toDouble(),
    _ => throw const FormatException('expected a number'),
  };

  static String? _optionalString(Object? value) => switch (value) {
    null => null,
    final String text => text,
    _ => throw const FormatException('expected a string'),
  };
}
