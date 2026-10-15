//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class HealthGet200Response {
  /// Returns a new [HealthGet200Response] instance.
  HealthGet200Response({
    required this.status,
  });

  HealthGet200ResponseStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is HealthGet200Response &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode);

  @override
  String toString() => 'HealthGet200Response[status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [HealthGet200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static HealthGet200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "HealthGet200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "HealthGet200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return HealthGet200Response(
        status: HealthGet200ResponseStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<HealthGet200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <HealthGet200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = HealthGet200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, HealthGet200Response> mapFromJson(dynamic json) {
    final map = <String, HealthGet200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = HealthGet200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of HealthGet200Response-objects as value to a dart map
  static Map<String, List<HealthGet200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<HealthGet200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = HealthGet200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
  };
}


class HealthGet200ResponseStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const HealthGet200ResponseStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const ok = HealthGet200ResponseStatusEnum._(r'ok');

  /// List of all possible values in this [enum][HealthGet200ResponseStatusEnum].
  static const values = <HealthGet200ResponseStatusEnum>[
    ok,
  ];

  static HealthGet200ResponseStatusEnum? fromJson(dynamic value) => HealthGet200ResponseStatusEnumTypeTransformer().decode(value);

  static List<HealthGet200ResponseStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <HealthGet200ResponseStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = HealthGet200ResponseStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [HealthGet200ResponseStatusEnum] to String,
/// and [decode] dynamic data back to [HealthGet200ResponseStatusEnum].
class HealthGet200ResponseStatusEnumTypeTransformer {
  factory HealthGet200ResponseStatusEnumTypeTransformer() => _instance ??= const HealthGet200ResponseStatusEnumTypeTransformer._();

  const HealthGet200ResponseStatusEnumTypeTransformer._();

  String encode(HealthGet200ResponseStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a HealthGet200ResponseStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  HealthGet200ResponseStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'ok': return HealthGet200ResponseStatusEnum.ok;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [HealthGet200ResponseStatusEnumTypeTransformer] instance.
  static HealthGet200ResponseStatusEnumTypeTransformer? _instance;
}


