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
    required this.role,
  });

  String firstName;

  String lastName;

  String email;

  String password;

  AuthRegisterPostRequestRoleEnum role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthRegisterPostRequest &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.email == email &&
          other.password == password &&
          other.role == role;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (firstName.hashCode) +
      (lastName.hashCode) +
      (email.hashCode) +
      (password.hashCode) +
      (role.hashCode);

  @override
  String toString() =>
      'AuthRegisterPostRequest[firstName=$firstName, lastName=$lastName, email=$email, password=$password, role=$role]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'firstName'] = this.firstName;
    json[r'lastName'] = this.lastName;
    json[r'email'] = this.email;
    json[r'password'] = this.password;
    json[r'role'] = this.role;
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
        role: AuthRegisterPostRequestRoleEnum.fromJson(json[r'role'])!,
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
    'role',
  };
}

class AuthRegisterPostRequestRoleEnum {
  /// Instantiate a new enum with the provided [value].
  const AuthRegisterPostRequestRoleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const student = AuthRegisterPostRequestRoleEnum._(r'student');
  static const professor = AuthRegisterPostRequestRoleEnum._(r'professor');

  /// List of all possible values in this [enum][AuthRegisterPostRequestRoleEnum].
  static const values = <AuthRegisterPostRequestRoleEnum>[
    student,
    professor,
  ];

  static AuthRegisterPostRequestRoleEnum? fromJson(dynamic value) =>
      AuthRegisterPostRequestRoleEnumTypeTransformer().decode(value);

  static List<AuthRegisterPostRequestRoleEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthRegisterPostRequestRoleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthRegisterPostRequestRoleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuthRegisterPostRequestRoleEnum] to String,
/// and [decode] dynamic data back to [AuthRegisterPostRequestRoleEnum].
class AuthRegisterPostRequestRoleEnumTypeTransformer {
  factory AuthRegisterPostRequestRoleEnumTypeTransformer() =>
      _instance ??= const AuthRegisterPostRequestRoleEnumTypeTransformer._();

  const AuthRegisterPostRequestRoleEnumTypeTransformer._();

  String encode(AuthRegisterPostRequestRoleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuthRegisterPostRequestRoleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuthRegisterPostRequestRoleEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'student':
          return AuthRegisterPostRequestRoleEnum.student;
        case r'professor':
          return AuthRegisterPostRequestRoleEnum.professor;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuthRegisterPostRequestRoleEnumTypeTransformer] instance.
  static AuthRegisterPostRequestRoleEnumTypeTransformer? _instance;
}
