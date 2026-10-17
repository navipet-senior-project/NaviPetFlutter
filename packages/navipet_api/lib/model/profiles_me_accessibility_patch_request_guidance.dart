//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAccessibilityPatchRequestGuidance {
  /// Returns a new [ProfilesMeAccessibilityPatchRequestGuidance] instance.
  ProfilesMeAccessibilityPatchRequestGuidance({
    this.voiceGuidance,
    this.hapticTurnAlerts,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? voiceGuidance;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? hapticTurnAlerts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMeAccessibilityPatchRequestGuidance &&
          other.voiceGuidance == voiceGuidance &&
          other.hapticTurnAlerts == hapticTurnAlerts;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (voiceGuidance == null ? 0 : voiceGuidance!.hashCode) +
      (hapticTurnAlerts == null ? 0 : hapticTurnAlerts!.hashCode);

  @override
  String toString() =>
      'ProfilesMeAccessibilityPatchRequestGuidance[voiceGuidance=$voiceGuidance, hapticTurnAlerts=$hapticTurnAlerts]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.voiceGuidance != null) {
      json[r'voiceGuidance'] = this.voiceGuidance;
    } else {
      json[r'voiceGuidance'] = null;
    }
    if (this.hapticTurnAlerts != null) {
      json[r'hapticTurnAlerts'] = this.hapticTurnAlerts;
    } else {
      json[r'hapticTurnAlerts'] = null;
    }
    return json;
  }

  /// Returns a new [ProfilesMeAccessibilityPatchRequestGuidance] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAccessibilityPatchRequestGuidance? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMeAccessibilityPatchRequestGuidance[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMeAccessibilityPatchRequestGuidance[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAccessibilityPatchRequestGuidance(
        voiceGuidance: mapValueOfType<bool>(json, r'voiceGuidance'),
        hapticTurnAlerts: mapValueOfType<bool>(json, r'hapticTurnAlerts'),
      );
    }
    return null;
  }

  static List<ProfilesMeAccessibilityPatchRequestGuidance> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ProfilesMeAccessibilityPatchRequestGuidance>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeAccessibilityPatchRequestGuidance.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAccessibilityPatchRequestGuidance> mapFromJson(
      dynamic json) {
    final map = <String, ProfilesMeAccessibilityPatchRequestGuidance>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ProfilesMeAccessibilityPatchRequestGuidance.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAccessibilityPatchRequestGuidance-objects as value to a dart map
  static Map<String, List<ProfilesMeAccessibilityPatchRequestGuidance>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ProfilesMeAccessibilityPatchRequestGuidance>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] =
            ProfilesMeAccessibilityPatchRequestGuidance.listFromJson(
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
