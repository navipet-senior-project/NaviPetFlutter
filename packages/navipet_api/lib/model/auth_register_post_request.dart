//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthRegisterPostRequest {
  /// Returns a new [AuthRegisterPostRequest] instance.
  AuthRegisterPostRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  String firstName;

  String lastName;

  String email;

  String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthRegisterPostRequest &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.email == email &&
          other.password == password;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (firstName.hashCode) +
      (lastName.hashCode) +
      (email.hashCode) +
      (password.hashCode);

  @override
  String toString() =>
      'AuthRegisterPostRequest[firstName=$firstName, lastName=$lastName, email=$email, password=$password]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'firstName'] = this.firstName;
    json[r'lastName'] = this.lastName;
    json[r'email'] = this.email;
    json[r'password'] = this.password;
    return json;
  }

  /// Returns a new [AuthRegisterPostRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthRegisterPostRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthRegisterPostRequest[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthRegisterPostRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthRegisterPostRequest(
        firstName: mapValueOfType<String>(json, r'firstName')!,
        lastName: mapValueOfType<String>(json, r'lastName')!,
        email: mapValueOfType<String>(json, r'email')!,
        password: mapValueOfType<String>(json, r'password')!,
      );
    }
    return null;
  }

  static List<AuthRegisterPostRequest> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthRegisterPostRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthRegisterPostRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthRegisterPostRequest> mapFromJson(dynamic json) {
    final map = <String, AuthRegisterPostRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthRegisterPostRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthRegisterPostRequest-objects as value to a dart map
  static Map<String, List<AuthRegisterPostRequest>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthRegisterPostRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthRegisterPostRequest.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'firstName',
    'lastName',
    'email',
    'password',
  };
}
