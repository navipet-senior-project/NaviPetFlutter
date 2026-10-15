//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthLoginPost502Response {
  /// Returns a new [AuthLoginPost502Response] instance.
  AuthLoginPost502Response({
    required this.error,
  });

  AuthLoginPost400ResponseError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthLoginPost502Response && other.error == error;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (error.hashCode);

  @override
  String toString() => 'AuthLoginPost502Response[error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'error'] = this.error;
    return json;
  }

  /// Returns a new [AuthLoginPost502Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthLoginPost502Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthLoginPost502Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthLoginPost502Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthLoginPost502Response(
        error: AuthLoginPost400ResponseError.fromJson(json[r'error'])!,
      );
    }
    return null;
  }

  static List<AuthLoginPost502Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthLoginPost502Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthLoginPost502Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthLoginPost502Response> mapFromJson(dynamic json) {
    final map = <String, AuthLoginPost502Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthLoginPost502Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthLoginPost502Response-objects as value to a dart map
  static Map<String, List<AuthLoginPost502Response>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthLoginPost502Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthLoginPost502Response.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'error',
  };
}
