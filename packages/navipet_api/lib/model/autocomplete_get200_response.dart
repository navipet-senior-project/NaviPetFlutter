//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200Response {
  /// Returns a new [AutocompleteGet200Response] instance.
  AutocompleteGet200Response({
    required this.query,
    this.results = const [],
    this.proximity,
  });

  String query;

  List<AutocompleteGet200ResponseResultsInner> results;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  AutocompleteGet200ResponseProximity? proximity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200Response &&
          other.query == query &&
          _deepEquality.equals(other.results, results) &&
          other.proximity == proximity;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (query.hashCode) +
      (results.hashCode) +
      (proximity == null ? 0 : proximity!.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200Response[query=$query, results=$results, proximity=$proximity]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'query'] = this.query;
    json[r'results'] = this.results;
    if (this.proximity != null) {
      json[r'proximity'] = this.proximity;
    } else {
      json[r'proximity'] = null;
    }
    return json;
  }

  /// Returns a new [AutocompleteGet200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200Response(
        query: mapValueOfType<String>(json, r'query')!,
        results: AutocompleteGet200ResponseResultsInner.listFromJson(
            json[r'results']),
        proximity:
            AutocompleteGet200ResponseProximity.fromJson(json[r'proximity']),
      );
    }
    return null;
  }

  static List<AutocompleteGet200Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AutocompleteGet200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200Response> mapFromJson(dynamic json) {
    final map = <String, AutocompleteGet200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AutocompleteGet200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200Response-objects as value to a dart map
  static Map<String, List<AutocompleteGet200Response>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AutocompleteGet200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AutocompleteGet200Response.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'query',
    'results',
  };
}
