//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseResultsInnerIndoor {
  /// Returns a new [AutocompleteGet200ResponseResultsInnerIndoor] instance.
  AutocompleteGet200ResponseResultsInnerIndoor({
    required this.mapCode,
    required this.frame,
    required this.doorKey,
    required this.floor,
    required this.position,
    required this.headingDeg,
  });

  String mapCode;

  AutocompleteGet200ResponseResultsInnerIndoorFrameEnum frame;

  String doorKey;

  String floor;

  AutocompleteGet200ResponseResultsInnerIndoorPosition position;

  /// Minimum value: 0
  num headingDeg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200ResponseResultsInnerIndoor &&
          other.mapCode == mapCode &&
          other.frame == frame &&
          other.doorKey == doorKey &&
          other.floor == floor &&
          other.position == position &&
          other.headingDeg == headingDeg;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (mapCode.hashCode) +
      (frame.hashCode) +
      (doorKey.hashCode) +
      (floor.hashCode) +
      (position.hashCode) +
      (headingDeg.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200ResponseResultsInnerIndoor[mapCode=$mapCode, frame=$frame, doorKey=$doorKey, floor=$floor, position=$position, headingDeg=$headingDeg]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'mapCode'] = this.mapCode;
    json[r'frame'] = this.frame;
    json[r'doorKey'] = this.doorKey;
    json[r'floor'] = this.floor;
    json[r'position'] = this.position;
    json[r'headingDeg'] = this.headingDeg;
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseResultsInnerIndoor] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseResultsInnerIndoor? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200ResponseResultsInnerIndoor[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200ResponseResultsInnerIndoor[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseResultsInnerIndoor(
        mapCode: mapValueOfType<String>(json, r'mapCode')!,
        frame: AutocompleteGet200ResponseResultsInnerIndoorFrameEnum.fromJson(
            json[r'frame'])!,
        doorKey: mapValueOfType<String>(json, r'doorKey')!,
        floor: mapValueOfType<String>(json, r'floor')!,
        position: AutocompleteGet200ResponseResultsInnerIndoorPosition.fromJson(
            json[r'position'])!,
        headingDeg: num.parse('${json[r'headingDeg']}'),
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseResultsInnerIndoor> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInnerIndoor>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerIndoor.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseResultsInnerIndoor> mapFromJson(
      dynamic json) {
    final map = <String, AutocompleteGet200ResponseResultsInnerIndoor>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            AutocompleteGet200ResponseResultsInnerIndoor.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseResultsInnerIndoor-objects as value to a dart map
  static Map<String, List<AutocompleteGet200ResponseResultsInnerIndoor>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AutocompleteGet200ResponseResultsInnerIndoor>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            AutocompleteGet200ResponseResultsInnerIndoor.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'mapCode',
    'frame',
    'doorKey',
    'floor',
    'position',
    'headingDeg',
  };
}

class AutocompleteGet200ResponseResultsInnerIndoorFrameEnum {
  /// Instantiate a new enum with the provided [value].
  const AutocompleteGet200ResponseResultsInnerIndoorFrameEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const multisetMapset =
      AutocompleteGet200ResponseResultsInnerIndoorFrameEnum._(
          r'multiset-mapset');

  /// List of all possible values in this [enum][AutocompleteGet200ResponseResultsInnerIndoorFrameEnum].
  static const values = <AutocompleteGet200ResponseResultsInnerIndoorFrameEnum>[
    multisetMapset,
  ];

  static AutocompleteGet200ResponseResultsInnerIndoorFrameEnum? fromJson(
          dynamic value) =>
      AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer()
          .decode(value);

  static List<AutocompleteGet200ResponseResultsInnerIndoorFrameEnum>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInnerIndoorFrameEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerIndoorFrameEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AutocompleteGet200ResponseResultsInnerIndoorFrameEnum] to String,
/// and [decode] dynamic data back to [AutocompleteGet200ResponseResultsInnerIndoorFrameEnum].
class AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer {
  factory AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer() =>
      _instance ??=
          const AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer
              ._();

  const AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer._();

  String encode(AutocompleteGet200ResponseResultsInnerIndoorFrameEnum data) =>
      data.value;

  /// Decodes a [dynamic value][data] to a AutocompleteGet200ResponseResultsInnerIndoorFrameEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AutocompleteGet200ResponseResultsInnerIndoorFrameEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'multiset-mapset':
          return AutocompleteGet200ResponseResultsInnerIndoorFrameEnum
              .multisetMapset;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer] instance.
  static AutocompleteGet200ResponseResultsInnerIndoorFrameEnumTypeTransformer?
      _instance;
}
