//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals {
  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals] instance.
  ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals({
    required this.highContrastMap,
    required this.largerMapLabels,
    required this.reduceMotion,
    required this.screenReaderDirections,
  });

  bool highContrastMap;

  bool largerMapLabels;

  bool reduceMotion;

  /// Screen-reader optimized directions.
  bool screenReaderDirections;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals &&
    other.highContrastMap == highContrastMap &&
    other.largerMapLabels == largerMapLabels &&
    other.reduceMotion == reduceMotion &&
    other.screenReaderDirections == screenReaderDirections;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (highContrastMap.hashCode) +
    (largerMapLabels.hashCode) +
    (reduceMotion.hashCode) +
    (screenReaderDirections.hashCode);

  @override
  String toString() => 'ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals[highContrastMap=$highContrastMap, largerMapLabels=$largerMapLabels, reduceMotion=$reduceMotion, screenReaderDirections=$screenReaderDirections]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'highContrastMap'] = this.highContrastMap;
      json[r'largerMapLabels'] = this.largerMapLabels;
      json[r'reduceMotion'] = this.reduceMotion;
      json[r'screenReaderDirections'] = this.screenReaderDirections;
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals(
        highContrastMap: mapValueOfType<bool>(json, r'highContrastMap')!,
        largerMapLabels: mapValueOfType<bool>(json, r'largerMapLabels')!,
        reduceMotion: mapValueOfType<bool>(json, r'reduceMotion')!,
        screenReaderDirections: mapValueOfType<bool>(json, r'screenReaderDirections')!,
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals> mapFromJson(dynamic json) {
    final map = <String, ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals-objects as value to a dart map
  static Map<String, List<ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'highContrastMap',
    'largerMapLabels',
    'reduceMotion',
    'screenReaderDirections',
  };
}

