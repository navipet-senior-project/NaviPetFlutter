//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseResultsInnerNavigation {
  /// Returns a new [AutocompleteGet200ResponseResultsInnerNavigation] instance.
  AutocompleteGet200ResponseResultsInnerNavigation({
    this.outdoorDestination,
    this.indoorDestinationId,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  AutocompleteGet200ResponseResultsInnerNavigationOutdoorDestination?
      outdoorDestination;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? indoorDestinationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200ResponseResultsInnerNavigation &&
          other.outdoorDestination == outdoorDestination &&
          other.indoorDestinationId == indoorDestinationId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (outdoorDestination == null ? 0 : outdoorDestination!.hashCode) +
      (indoorDestinationId == null ? 0 : indoorDestinationId!.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200ResponseResultsInnerNavigation[outdoorDestination=$outdoorDestination, indoorDestinationId=$indoorDestinationId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.outdoorDestination != null) {
      json[r'outdoorDestination'] = this.outdoorDestination;
    } else {
      json[r'outdoorDestination'] = null;
    }
    if (this.indoorDestinationId != null) {
      json[r'indoorDestinationId'] = this.indoorDestinationId;
    } else {
      json[r'indoorDestinationId'] = null;
    }
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseResultsInnerNavigation] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseResultsInnerNavigation? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200ResponseResultsInnerNavigation[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200ResponseResultsInnerNavigation[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseResultsInnerNavigation(
        outdoorDestination:
            AutocompleteGet200ResponseResultsInnerNavigationOutdoorDestination
                .fromJson(json[r'outdoorDestination']),
        indoorDestinationId:
            mapValueOfType<String>(json, r'indoorDestinationId'),
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseResultsInnerNavigation> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInnerNavigation>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerNavigation.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseResultsInnerNavigation>
      mapFromJson(dynamic json) {
    final map = <String, AutocompleteGet200ResponseResultsInnerNavigation>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AutocompleteGet200ResponseResultsInnerNavigation.fromJson(
            entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseResultsInnerNavigation-objects as value to a dart map
  static Map<String, List<AutocompleteGet200ResponseResultsInnerNavigation>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map =
        <String, List<AutocompleteGet200ResponseResultsInnerNavigation>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            AutocompleteGet200ResponseResultsInnerNavigation.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
