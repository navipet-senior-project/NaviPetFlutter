import 'dart:convert';

/// Bridge contract v2 between the app and the Unity AR runtime.
///
/// Every pose is in the MultiSet MapSet frame (left-handed, +Y up, metres,
/// origin at the Floor 1 2 map root, floors 1-3 share it), the same frame as the backend's door
/// points. Nothing on either side of the bridge converts.
class IndoorArVector3 {
  const IndoorArVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'z': z};
}

/// A short-lived MultiSet token the backend minted for one AR session. Held in
/// memory only; [toString] hides the secret so it cannot reach a log by accident.
class IndoorArToken {
  const IndoorArToken({required this.token, required this.expiresOn});

  final String token;
  final DateTime expiresOn;

  Map<String, Object?> toJson() => {
    'token': token,
    'expiresOn': expiresOn.toUtc().toIso8601String(),
  };

  @override
  String toString() => 'IndoorArToken(expiresOn: $expiresOn)';
}

/// The floor the user confirmed they stand on, with the barometer's verdict on
/// whether the phone has stayed on one level since. Optional on a request: Unity
/// trusts it only when settled, not moved and fresh, so anything less is the
/// same as sending nothing. Never the destination floor; no absolute or raw
/// pressure, location or wall-clock time is carried.
class IndoorArStartFloor {
  IndoorArStartFloor({
    required this.floor,
    required this.ageS,
    required this.settled,
    required this.moved,
    required this.sampleAgeS,
  }) {
    if (floor.isEmpty) throw ArgumentError('floor must not be empty');
    // Negated range checks so NaN is rejected too.
    if (!(ageS >= 0 && ageS.isFinite)) {
      throw ArgumentError.value(ageS, 'ageS', 'must be finite and >= 0');
    }
    if (!(sampleAgeS >= 0 && sampleAgeS.isFinite)) {
      throw ArgumentError.value(
        sampleAgeS,
        'sampleAgeS',
        'must be finite and >= 0',
      );
    }
  }

  final String floor;

  /// Seconds since the user confirmed the floor, on a monotonic clock.
  final double ageS;
  final bool settled;
  final bool moved;

  /// Seconds since the newest barometer sample.
  final double sampleAgeS;

  Map<String, Object?> toJson() => {
    'startFloor': floor,
    'startFloorAgeS': ageS,
    'pressureSinceStart': {
      'settled': settled,
      'moved': moved,
      'sampleAgeS': sampleAgeS,
    },
  };
}

/// One AR session: a saved door, or localization with no door pose.
class IndoorArRequest {
  IndoorArRequest({
    required this.room,
    required this.doorKey,
    required this.floor,
    required this.position,
    required this.headingDeg,
    required this.mapCode,
    required this.frame,
    this.arToken,
    this.startFloor,
  }) : mode = null {
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

  /// Scan to find the phone. Omits door pose fields so none can be invented.
  IndoorArRequest.localize({
    this.room = '',
    this.floor = '',
    required this.mapCode,
    required this.frame,
    this.arToken,
    this.startFloor,
  }) : mode = localizeMode,
       doorKey = '',
       position = const IndoorArVector3(0, 0, 0),
       headingDeg = 0 {
    if (mapCode.isEmpty || frame.isEmpty) {
      throw ArgumentError('mapCode and frame must not be empty');
    }
  }

  static const schemaVersion = 2;

  /// Unity build map. Used only when the backend sent no door pose.
  static const buildMapCode = 'MSET_XTBY7AM7ZK77';
  static const buildFrame = 'multiset-mapset';
  static const localizeMode = 'localize';

  /// Sent on destination requests: this app accepts a distance-less `arrived`
  /// that carries the destination's `signRoom`. A runtime that does not read it
  /// must keep sending `checkDistanceM`, which older app builds still require.
  static const signArrivalCapability = 'signArrival';

  /// `localize` or null for a destination request. Null stays off the JSON.
  final String? mode;
  final String room;

  /// Empty only for [IndoorArRequest.localize]. Not serialized in that mode.
  final String doorKey;
  final String floor;

  /// Zero only for [IndoorArRequest.localize]. Not a door and not serialized.
  final IndoorArVector3 position;
  final double headingDeg;
  final String mapCode;
  final String frame;

  /// Set on every real launch (v2). Null only for debug launches that need no
  /// localisation, such as the transport spike.
  final IndoorArToken? arToken;

  /// Null when the user skipped the floor question or the barometer gave
  /// nothing; the fields then stay off the JSON and Unity behaves as before.
  final IndoorArStartFloor? startFloor;

  bool get isLocalize => mode == localizeMode;

  IndoorArRequest withArToken(IndoorArToken token) =>
      _copy(arToken: token, startFloor: startFloor);

  IndoorArRequest withStartFloor(IndoorArStartFloor? value) =>
      _copy(arToken: arToken, startFloor: value);

  IndoorArRequest _copy({
    required IndoorArToken? arToken,
    required IndoorArStartFloor? startFloor,
  }) => isLocalize
      ? IndoorArRequest.localize(
          room: room,
          floor: floor,
          mapCode: mapCode,
          frame: frame,
          arToken: arToken,
          startFloor: startFloor,
        )
      : IndoorArRequest(
          room: room,
          doorKey: doorKey,
          floor: floor,
          position: position,
          headingDeg: headingDeg,
          mapCode: mapCode,
          frame: frame,
          arToken: arToken,
          startFloor: startFloor,
        );

  Map<String, Object?> toJson() => isLocalize
      ? {
          'schemaVersion': schemaVersion,
          'mode': localizeMode,
          'mapCode': mapCode,
          'frame': frame,
          if (room.isNotEmpty) 'room': room,
          if (floor.isNotEmpty) 'floor': floor,
          if (arToken != null) 'arToken': arToken!.toJson(),
          if (startFloor != null) ...startFloor!.toJson(),
        }
      : {
          'schemaVersion': schemaVersion,
          'room': room,
          'doorKey': doorKey,
          'floor': floor,
          'position': position.toJson(),
          'headingDeg': headingDeg,
          'mapCode': mapCode,
          'frame': frame,
          'capabilities': [signArrivalCapability],
          if (arToken != null) 'arToken': arToken!.toJson(),
          if (startFloor != null) ...startFloor!.toJson(),
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
    this.signRoom,
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

  /// Horizontal distance from the phone to the door point, `arrived` only. Null
  /// when the runtime confirmed the destination sign without a tracked pose.
  final double? checkDistanceM;

  /// Room the runtime read from a sign, `arrived` only. Evidence, not a pose.
  final String? signRoom;
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
    final signRoom = _optionalString(json['signRoom']);
    // No distance is allowed only when a sign confirmed the arrival.
    if (status == IndoorArStatus.arrived &&
        (distance == null
            ? signRoom == null || signRoom.isEmpty
            : distance < 0)) {
      throw const FormatException(
        'arrived needs checkDistanceM >= 0 or a signRoom',
      );
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
      signRoom: status == IndoorArStatus.arrived ? signRoom : null,
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
