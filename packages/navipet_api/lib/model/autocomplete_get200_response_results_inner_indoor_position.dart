//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseResultsInnerIndoorPosition {
  /// Returns a new [AutocompleteGet200ResponseResultsInnerIndoorPosition] instance.
  AutocompleteGet200ResponseResultsInnerIndoorPosition({
    required this.x,
    required this.y,
    required this.z,
  });

  num x;

  num y;

  num z;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200ResponseResultsInnerIndoorPosition &&
          other.x == x &&
          other.y == y &&
          other.z == z;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (x.hashCode) + (y.hashCode) + (z.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200ResponseResultsInnerIndoorPosition[x=$x, y=$y, z=$z]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'x'] = this.x;
    json[r'y'] = this.y;
    json[r'z'] = this.z;
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseResultsInnerIndoorPosition] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseResultsInnerIndoorPosition? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200ResponseResultsInnerIndoorPosition[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200ResponseResultsInnerIndoorPosition[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseResultsInnerIndoorPosition(
        x: num.parse('${json[r'x']}'),
        y: num.parse('${json[r'y']}'),
        z: num.parse('${json[r'z']}'),
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseResultsInnerIndoorPosition>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInnerIndoorPosition>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerIndoorPosition.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseResultsInnerIndoorPosition>
      mapFromJson(dynamic json) {
    final map =
        <String, AutocompleteGet200ResponseResultsInnerIndoorPosition>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            AutocompleteGet200ResponseResultsInnerIndoorPosition.fromJson(
                entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseResultsInnerIndoorPosition-objects as value to a dart map
  static Map<String, List<AutocompleteGet200ResponseResultsInnerIndoorPosition>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map =
        <String, List<AutocompleteGet200ResponseResultsInnerIndoorPosition>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            AutocompleteGet200ResponseResultsInnerIndoorPosition.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'x',
    'y',
    'z',
  };
}
