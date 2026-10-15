//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthResetPasswordPostRequest {
  /// Returns a new [AuthResetPasswordPostRequest] instance.
  AuthResetPasswordPostRequest({
    required this.newPassword,
    required this.confirmPassword,
  });

  String newPassword;

  String confirmPassword;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuthResetPasswordPostRequest &&
    other.newPassword == newPassword &&
    other.confirmPassword == confirmPassword;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (newPassword.hashCode) +
    (confirmPassword.hashCode);

  @override
  String toString() => 'AuthResetPasswordPostRequest[newPassword=$newPassword, confirmPassword=$confirmPassword]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'newPassword'] = this.newPassword;
      json[r'confirmPassword'] = this.confirmPassword;
    return json;
  }

  /// Returns a new [AuthResetPasswordPostRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthResetPasswordPostRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AuthResetPasswordPostRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AuthResetPasswordPostRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthResetPasswordPostRequest(
        newPassword: mapValueOfType<String>(json, r'newPassword')!,
        confirmPassword: mapValueOfType<String>(json, r'confirmPassword')!,
      );
    }
    return null;
  }

  static List<AuthResetPasswordPostRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuthResetPasswordPostRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthResetPasswordPostRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthResetPasswordPostRequest> mapFromJson(dynamic json) {
    final map = <String, AuthResetPasswordPostRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthResetPasswordPostRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthResetPasswordPostRequest-objects as value to a dart map
  static Map<String, List<AuthResetPasswordPostRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AuthResetPasswordPostRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthResetPasswordPostRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'newPassword',
    'confirmPassword',
  };
}

