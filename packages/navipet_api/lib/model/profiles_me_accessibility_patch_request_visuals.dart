//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityPatchRequestVisuals {
  /// Returns a new [ProfilesMeAccessibilityPatchRequestVisuals] instance.
  ProfilesMeAccessibilityPatchRequestVisuals({
    this.highContrastMap,
    this.largerMapLabels,
    this.reduceMotion,
    this.screenReaderDirections,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? highContrastMap;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? largerMapLabels;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? reduceMotion;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? screenReaderDirections;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMeAccessibilityPatchRequestVisuals &&
          other.highContrastMap == highContrastMap &&
          other.largerMapLabels == largerMapLabels &&
          other.reduceMotion == reduceMotion &&
          other.screenReaderDirections == screenReaderDirections;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (highContrastMap == null ? 0 : highContrastMap!.hashCode) +
      (largerMapLabels == null ? 0 : largerMapLabels!.hashCode) +
      (reduceMotion == null ? 0 : reduceMotion!.hashCode) +
      (screenReaderDirections == null ? 0 : screenReaderDirections!.hashCode);

  @override
  String toString() =>
      'ProfilesMeAccessibilityPatchRequestVisuals[highContrastMap=$highContrastMap, largerMapLabels=$largerMapLabels, reduceMotion=$reduceMotion, screenReaderDirections=$screenReaderDirections]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.highContrastMap != null) {
      json[r'highContrastMap'] = this.highContrastMap;
    } else {
      json[r'highContrastMap'] = null;
    }
    if (this.largerMapLabels != null) {
      json[r'largerMapLabels'] = this.largerMapLabels;
    } else {
      json[r'largerMapLabels'] = null;
    }
    if (this.reduceMotion != null) {
      json[r'reduceMotion'] = this.reduceMotion;
    } else {
      json[r'reduceMotion'] = null;
    }
    if (this.screenReaderDirections != null) {
      json[r'screenReaderDirections'] = this.screenReaderDirections;
    } else {
      json[r'screenReaderDirections'] = null;
    }
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityPatchRequestVisuals] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityPatchRequestVisuals? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMeAccessibilityPatchRequestVisuals[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMeAccessibilityPatchRequestVisuals[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityPatchRequestVisuals(
        highContrastMap: mapValueOfType<bool>(json, r'highContrastMap'),
        largerMapLabels: mapValueOfType<bool>(json, r'largerMapLabels'),
        reduceMotion: mapValueOfType<bool>(json, r'reduceMotion'),
        screenReaderDirections:
            mapValueOfType<bool>(json, r'screenReaderDirections'),
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityPatchRequestVisuals> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ProfilesMeAccessibilityPatchRequestVisuals>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeAccessibilityPatchRequestVisuals.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityPatchRequestVisuals> mapFromJson(
      dynamic json) {
    final map = <String, ProfilesMeAccessibilityPatchRequestVisuals>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ProfilesMeAccessibilityPatchRequestVisuals.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityPatchRequestVisuals-objects as value to a dart map
  static Map<String, List<ProfilesMeAccessibilityPatchRequestVisuals>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ProfilesMeAccessibilityPatchRequestVisuals>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            ProfilesMeAccessibilityPatchRequestVisuals.listFromJson(
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
