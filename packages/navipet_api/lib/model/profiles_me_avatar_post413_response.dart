//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeAvatarPost413Response {
  /// Returns a new [ProfilesMeAvatarPost413Response] instance.
  ProfilesMeAvatarPost413Response({
    required this.error,
  });

  AuthLoginPost400ResponseError error;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProfilesMeAvatarPost413Response &&
    other.error == error;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (error.hashCode);

  @override
  String toString() => 'ProfilesMeAvatarPost413Response[error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'error'] = this.error;
    return json;
  }

  /// Returns a new [ProfilesMeAvatarPost413Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeAvatarPost413Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ProfilesMeAvatarPost413Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ProfilesMeAvatarPost413Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeAvatarPost413Response(
        error: AuthLoginPost400ResponseError.fromJson(json[r'error'])!,
      );
    }
    return null;
  }

  static List<ProfilesMeAvatarPost413Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfilesMeAvatarPost413Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeAvatarPost413Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeAvatarPost413Response> mapFromJson(dynamic json) {
    final map = <String, ProfilesMeAvatarPost413Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfilesMeAvatarPost413Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeAvatarPost413Response-objects as value to a dart map
  static Map<String, List<ProfilesMeAvatarPost413Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ProfilesMeAvatarPost413Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfilesMeAvatarPost413Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'error',
  };
}

