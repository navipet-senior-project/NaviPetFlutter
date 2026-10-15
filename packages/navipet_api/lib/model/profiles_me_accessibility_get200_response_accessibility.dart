//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityGet200ResponseAccessibility {
  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibility] instance.
  ProfilesMeAccessibilityGet200ResponseAccessibility({
    required this.mobility,
    required this.guidance,
    required this.visuals,
  });

  ProfilesMeAccessibilityGet200ResponseAccessibilityMobility mobility;

  ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance guidance;

  ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals visuals;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMeAccessibilityGet200ResponseAccessibility &&
          other.mobility == mobility &&
          other.guidance == guidance &&
          other.visuals == visuals;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (mobility.hashCode) + (guidance.hashCode) + (visuals.hashCode);

  @override
  String toString() =>
      'ProfilesMeAccessibilityGet200ResponseAccessibility[mobility=$mobility, guidance=$guidance, visuals=$visuals]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'mobility'] = this.mobility;
    json[r'guidance'] = this.guidance;
    json[r'visuals'] = this.visuals;
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibility] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityGet200ResponseAccessibility? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibility[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibility[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityGet200ResponseAccessibility(
        mobility:
            ProfilesMeAccessibilityGet200ResponseAccessibilityMobility.fromJson(
                json[r'mobility'])!,
        guidance:
            ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance.fromJson(
                json[r'guidance'])!,
        visuals:
            ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals.fromJson(
                json[r'visuals'])!,
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityGet200ResponseAccessibility> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ProfilesMeAccessibilityGet200ResponseAccessibility>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibility.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityGet200ResponseAccessibility>
      mapFromJson(dynamic json) {
    final map = <String, ProfilesMeAccessibilityGet200ResponseAccessibility>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibility.fromJson(
                entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityGet200ResponseAccessibility-objects as value to a dart map
  static Map<String, List<ProfilesMeAccessibilityGet200ResponseAccessibility>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map =
        <String, List<ProfilesMeAccessibilityGet200ResponseAccessibility>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            ProfilesMeAccessibilityGet200ResponseAccessibility.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'mobility',
    'guidance',
    'visuals',
  };
}
