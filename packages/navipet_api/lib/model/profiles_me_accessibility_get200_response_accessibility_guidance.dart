//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance {
  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance] instance.
  ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance({
    required this.voiceGuidance,
    required this.hapticTurnAlerts,
  });

  /// Spoken turn-by-turn directions.
  bool voiceGuidance;

  bool hapticTurnAlerts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance &&
          other.voiceGuidance == voiceGuidance &&
          other.hapticTurnAlerts == hapticTurnAlerts;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (voiceGuidance.hashCode) + (hapticTurnAlerts.hashCode);

  @override
  String toString() =>
      'ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance[voiceGuidance=$voiceGuidance, hapticTurnAlerts=$hapticTurnAlerts]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'voiceGuidance'] = this.voiceGuidance;
    json[r'hapticTurnAlerts'] = this.hapticTurnAlerts;
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance? fromJson(
      dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance(
        voiceGuidance: mapValueOfType<bool>(json, r'voiceGuidance')!,
        hapticTurnAlerts: mapValueOfType<bool>(json, r'hapticTurnAlerts')!,
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>
      listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result =
        <ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance.fromJson(
                row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>
      mapFromJson(dynamic json) {
    final map =
        <String, ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance.fromJson(
                entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance-objects as value to a dart map
  static Map<String,
          List<ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String,
        List<ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance
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
    'voiceGuidance',
    'hapticTurnAlerts',
  };
}
