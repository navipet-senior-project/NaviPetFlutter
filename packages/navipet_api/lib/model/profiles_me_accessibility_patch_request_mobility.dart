//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityPatchRequestMobility {
  /// Returns a new [ProfilesMeAccessibilityPatchRequestMobility] instance.
  ProfilesMeAccessibilityPatchRequestMobility({
    this.accessibleRoutes,
    this.avoidStairs,
    this.preferElevators,
    this.avoidSteepSlopes,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? accessibleRoutes;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? avoidStairs;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? preferElevators;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? avoidSteepSlopes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProfilesMeAccessibilityPatchRequestMobility &&
    other.accessibleRoutes == accessibleRoutes &&
    other.avoidStairs == avoidStairs &&
    other.preferElevators == preferElevators &&
    other.avoidSteepSlopes == avoidSteepSlopes;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (accessibleRoutes == null ? 0 : accessibleRoutes!.hashCode) +
    (avoidStairs == null ? 0 : avoidStairs!.hashCode) +
    (preferElevators == null ? 0 : preferElevators!.hashCode) +
    (avoidSteepSlopes == null ? 0 : avoidSteepSlopes!.hashCode);

  @override
  String toString() => 'ProfilesMeAccessibilityPatchRequestMobility[accessibleRoutes=$accessibleRoutes, avoidStairs=$avoidStairs, preferElevators=$preferElevators, avoidSteepSlopes=$avoidSteepSlopes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.accessibleRoutes != null) {
      json[r'accessibleRoutes'] = this.accessibleRoutes;
    } else {
      json[r'accessibleRoutes'] = null;
    }
    if (this.avoidStairs != null) {
      json[r'avoidStairs'] = this.avoidStairs;
    } else {
      json[r'avoidStairs'] = null;
    }
    if (this.preferElevators != null) {
      json[r'preferElevators'] = this.preferElevators;
    } else {
      json[r'preferElevators'] = null;
    }
    if (this.avoidSteepSlopes != null) {
      json[r'avoidSteepSlopes'] = this.avoidSteepSlopes;
    } else {
      json[r'avoidSteepSlopes'] = null;
    }
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityPatchRequestMobility] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityPatchRequestMobility? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ProfilesMeAccessibilityPatchRequestMobility[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ProfilesMeAccessibilityPatchRequestMobility[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityPatchRequestMobility(
        accessibleRoutes: mapValueOfType<bool>(json, r'accessibleRoutes'),
        avoidStairs: mapValueOfType<bool>(json, r'avoidStairs'),
        preferElevators: mapValueOfType<bool>(json, r'preferElevators'),
        avoidSteepSlopes: mapValueOfType<bool>(json, r'avoidSteepSlopes'),
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityPatchRequestMobility> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfilesMeAccessibilityPatchRequestMobility>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeAccessibilityPatchRequestMobility.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityPatchRequestMobility> mapFromJson(dynamic json) {
    final map = <String, ProfilesMeAccessibilityPatchRequestMobility>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfilesMeAccessibilityPatchRequestMobility.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityPatchRequestMobility-objects as value to a dart map
  static Map<String, List<ProfilesMeAccessibilityPatchRequestMobility>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ProfilesMeAccessibilityPatchRequestMobility>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfilesMeAccessibilityPatchRequestMobility.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

