//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseResultsInnerNavigationFootprint {
  /// Returns a new [AutocompleteGet200ResponseResultsInnerNavigationFootprint] instance.
  AutocompleteGet200ResponseResultsInnerNavigationFootprint({
    required this.type,
    this.coordinates = const [],
  });

  AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum type;

  List<List<List<num>>> coordinates;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200ResponseResultsInnerNavigationFootprint &&
          other.type == type &&
          _deepEquality.equals(other.coordinates, coordinates);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (type.hashCode) + (coordinates.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200ResponseResultsInnerNavigationFootprint[type=$type, coordinates=$coordinates]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'type'] = this.type;
    json[r'coordinates'] = this.coordinates;
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseResultsInnerNavigationFootprint] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseResultsInnerNavigationFootprint? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200ResponseResultsInnerNavigationFootprint[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200ResponseResultsInnerNavigationFootprint[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseResultsInnerNavigationFootprint(
        type: AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum
            .fromJson(json[r'type'])!,
        coordinates: json[r'coordinates'] is List
            ? (json[r'coordinates'] as List)
                .map((e) => List.listFromJson(json[r'coordinates']))
                .toList()
            : const [],
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseResultsInnerNavigationFootprint>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result =
        <AutocompleteGet200ResponseResultsInnerNavigationFootprint>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerNavigationFootprint.fromJson(
                row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseResultsInnerNavigationFootprint>
      mapFromJson(dynamic json) {
    final map =
        <String, AutocompleteGet200ResponseResultsInnerNavigationFootprint>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            AutocompleteGet200ResponseResultsInnerNavigationFootprint.fromJson(
                entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseResultsInnerNavigationFootprint-objects as value to a dart map
  static Map<String,
          List<AutocompleteGet200ResponseResultsInnerNavigationFootprint>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String,
        List<AutocompleteGet200ResponseResultsInnerNavigationFootprint>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            AutocompleteGet200ResponseResultsInnerNavigationFootprint
                .listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'type',
    'coordinates',
  };
}

class AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum._(
      this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const polygon =
      AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum._(
          r'Polygon');

  /// List of all possible values in this [enum][AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum].
  static const values =
      <AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum>[
    polygon,
  ];

  static AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum?
      fromJson(dynamic value) =>
          AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer()
              .decode(value);

  static List<AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result =
        <AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum
                .fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum] to String,
/// and [decode] dynamic data back to [AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum].
class AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer {
  factory AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer() =>
      _instance ??=
          const AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer
              ._();

  const AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer._();

  String encode(
          AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum
              data) =>
      data.value;

  /// Decodes a [dynamic value][data] to a AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum? decode(
      dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'Polygon':
          return AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnum
              .polygon;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer] instance.
  static AutocompleteGet200ResponseResultsInnerNavigationFootprintTypeEnumTypeTransformer?
      _instance;
}
