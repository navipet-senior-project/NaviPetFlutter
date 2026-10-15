//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityGet200ResponseAccessibilityMobility {
  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityMobility] instance.
  ProfilesMeAccessibilityGet200ResponseAccessibilityMobility({
    required this.accessibleRoutes,
    required this.avoidStairs,
    required this.preferElevators,
    required this.avoidSteepSlopes,
  });

  /// Prioritize wheelchair and ramp access.
  bool accessibleRoutes;

  bool avoidStairs;

  bool preferElevators;

  bool avoidSteepSlopes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMeAccessibilityGet200ResponseAccessibilityMobility &&
          other.accessibleRoutes == accessibleRoutes &&
          other.avoidStairs == avoidStairs &&
          other.preferElevators == preferElevators &&
          other.avoidSteepSlopes == avoidSteepSlopes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accessibleRoutes.hashCode) +
      (avoidStairs.hashCode) +
      (preferElevators.hashCode) +
      (avoidSteepSlopes.hashCode);

  @override
  String toString() =>
      'ProfilesMeAccessibilityGet200ResponseAccessibilityMobility[accessibleRoutes=$accessibleRoutes, avoidStairs=$avoidStairs, preferElevators=$preferElevators, avoidSteepSlopes=$avoidSteepSlopes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'accessibleRoutes'] = this.accessibleRoutes;
    json[r'avoidStairs'] = this.avoidStairs;
    json[r'preferElevators'] = this.preferElevators;
    json[r'avoidSteepSlopes'] = this.avoidSteepSlopes;
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityMobility] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityGet200ResponseAccessibilityMobility? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityMobility[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityMobility[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityGet200ResponseAccessibilityMobility(
        accessibleRoutes: mapValueOfType<bool>(json, r'accessibleRoutes')!,
        avoidStairs: mapValueOfType<bool>(json, r'avoidStairs')!,
        preferElevators: mapValueOfType<bool>(json, r'preferElevators')!,
        avoidSteepSlopes: mapValueOfType<bool>(json, r'avoidSteepSlopes')!,
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result =
        <ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibilityMobility.fromJson(
                row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>
      mapFromJson(dynamic json) {
    final map =
        <String, ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibilityMobility.fromJson(
                entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityGet200ResponseAccessibilityMobility-objects as value to a dart map
  static Map<String,
          List<ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String,
        List<ProfilesMeAccessibilityGet200ResponseAccessibilityMobility>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            ProfilesMeAccessibilityGet200ResponseAccessibilityMobility
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
    'accessibleRoutes',
    'avoidStairs',
    'preferElevators',
    'avoidSteepSlopes',
  };
}
