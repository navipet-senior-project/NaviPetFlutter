//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseProximity {
  /// Returns a new [AutocompleteGet200ResponseProximity] instance.
  AutocompleteGet200ResponseProximity({
    required this.intent,
    required this.status,
    required this.radiusMeters,
  });

  AutocompleteGet200ResponseProximityIntentEnum intent;

  AutocompleteGet200ResponseProximityStatusEnum status;

  /// Minimum value: 1
  int radiusMeters;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AutocompleteGet200ResponseProximity &&
    other.intent == intent &&
    other.status == status &&
    other.radiusMeters == radiusMeters;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (intent.hashCode) +
    (status.hashCode) +
    (radiusMeters.hashCode);

  @override
  String toString() => 'AutocompleteGet200ResponseProximity[intent=$intent, status=$status, radiusMeters=$radiusMeters]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'intent'] = this.intent;
      json[r'status'] = this.status;
      json[r'radiusMeters'] = this.radiusMeters;
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseProximity] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseProximity? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AutocompleteGet200ResponseProximity[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AutocompleteGet200ResponseProximity[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseProximity(
        intent: AutocompleteGet200ResponseProximityIntentEnum.fromJson(json[r'intent'])!,
        status: AutocompleteGet200ResponseProximityStatusEnum.fromJson(json[r'status'])!,
        radiusMeters: mapValueOfType<int>(json, r'radiusMeters')!,
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseProximity> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AutocompleteGet200ResponseProximity>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AutocompleteGet200ResponseProximity.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseProximity> mapFromJson(dynamic json) {
    final map = <String, AutocompleteGet200ResponseProximity>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AutocompleteGet200ResponseProximity.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseProximity-objects as value to a dart map
  static Map<String, List<AutocompleteGet200ResponseProximity>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AutocompleteGet200ResponseProximity>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AutocompleteGet200ResponseProximity.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'intent',
    'status',
    'radiusMeters',
  };
}


class AutocompleteGet200ResponseProximityIntentEnum {
  /// Instantiate a new enum with the provided [value].
  const AutocompleteGet200ResponseProximityIntentEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const restroom = AutocompleteGet200ResponseProximityIntentEnum._(r'restroom');
  static const food = AutocompleteGet200ResponseProximityIntentEnum._(r'food');
  static const parking = AutocompleteGet200ResponseProximityIntentEnum._(r'parking');
  static const busStop = AutocompleteGet200ResponseProximityIntentEnum._(r'bus_stop');
  static const coffee = AutocompleteGet200ResponseProximityIntentEnum._(r'coffee');

  /// List of all possible values in this [enum][AutocompleteGet200ResponseProximityIntentEnum].
  static const values = <AutocompleteGet200ResponseProximityIntentEnum>[
    restroom,
    food,
    parking,
    busStop,
    coffee,
  ];

  static AutocompleteGet200ResponseProximityIntentEnum? fromJson(dynamic value) => AutocompleteGet200ResponseProximityIntentEnumTypeTransformer().decode(value);

  static List<AutocompleteGet200ResponseProximityIntentEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AutocompleteGet200ResponseProximityIntentEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AutocompleteGet200ResponseProximityIntentEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AutocompleteGet200ResponseProximityIntentEnum] to String,
/// and [decode] dynamic data back to [AutocompleteGet200ResponseProximityIntentEnum].
class AutocompleteGet200ResponseProximityIntentEnumTypeTransformer {
  factory AutocompleteGet200ResponseProximityIntentEnumTypeTransformer() => _instance ??= const AutocompleteGet200ResponseProximityIntentEnumTypeTransformer._();

  const AutocompleteGet200ResponseProximityIntentEnumTypeTransformer._();

  String encode(AutocompleteGet200ResponseProximityIntentEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AutocompleteGet200ResponseProximityIntentEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AutocompleteGet200ResponseProximityIntentEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'restroom': return AutocompleteGet200ResponseProximityIntentEnum.restroom;
        case r'food': return AutocompleteGet200ResponseProximityIntentEnum.food;
        case r'parking': return AutocompleteGet200ResponseProximityIntentEnum.parking;
        case r'bus_stop': return AutocompleteGet200ResponseProximityIntentEnum.busStop;
        case r'coffee': return AutocompleteGet200ResponseProximityIntentEnum.coffee;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AutocompleteGet200ResponseProximityIntentEnumTypeTransformer] instance.
  static AutocompleteGet200ResponseProximityIntentEnumTypeTransformer? _instance;
}



class AutocompleteGet200ResponseProximityStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AutocompleteGet200ResponseProximityStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const ok = AutocompleteGet200ResponseProximityStatusEnum._(r'ok');

  /// List of all possible values in this [enum][AutocompleteGet200ResponseProximityStatusEnum].
  static const values = <AutocompleteGet200ResponseProximityStatusEnum>[
    ok,
  ];

  static AutocompleteGet200ResponseProximityStatusEnum? fromJson(dynamic value) => AutocompleteGet200ResponseProximityStatusEnumTypeTransformer().decode(value);

  static List<AutocompleteGet200ResponseProximityStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AutocompleteGet200ResponseProximityStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AutocompleteGet200ResponseProximityStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AutocompleteGet200ResponseProximityStatusEnum] to String,
/// and [decode] dynamic data back to [AutocompleteGet200ResponseProximityStatusEnum].
class AutocompleteGet200ResponseProximityStatusEnumTypeTransformer {
  factory AutocompleteGet200ResponseProximityStatusEnumTypeTransformer() => _instance ??= const AutocompleteGet200ResponseProximityStatusEnumTypeTransformer._();

  const AutocompleteGet200ResponseProximityStatusEnumTypeTransformer._();

  String encode(AutocompleteGet200ResponseProximityStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AutocompleteGet200ResponseProximityStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AutocompleteGet200ResponseProximityStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'ok': return AutocompleteGet200ResponseProximityStatusEnum.ok;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AutocompleteGet200ResponseProximityStatusEnumTypeTransformer] instance.
  static AutocompleteGet200ResponseProximityStatusEnumTypeTransformer? _instance;
}


