//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthVerifyOtpPost422Response {
  /// Returns a new [AuthVerifyOtpPost422Response] instance.
  AuthVerifyOtpPost422Response({
    required this.error,
  });

  AuthLoginPost400ResponseError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthVerifyOtpPost422Response && other.error == error;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (error.hashCode);

  @override
  String toString() => 'AuthVerifyOtpPost422Response[error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'error'] = this.error;
    return json;
  }

  /// Returns a new [AuthVerifyOtpPost422Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthVerifyOtpPost422Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthVerifyOtpPost422Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthVerifyOtpPost422Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthVerifyOtpPost422Response(
        error: AuthLoginPost400ResponseError.fromJson(json[r'error'])!,
      );
    }
    return null;
  }

  static List<AuthVerifyOtpPost422Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthVerifyOtpPost422Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthVerifyOtpPost422Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthVerifyOtpPost422Response> mapFromJson(dynamic json) {
    final map = <String, AuthVerifyOtpPost422Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthVerifyOtpPost422Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthVerifyOtpPost422Response-objects as value to a dart map
  static Map<String, List<AuthVerifyOtpPost422Response>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthVerifyOtpPost422Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthVerifyOtpPost422Response.listFromJson(
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
