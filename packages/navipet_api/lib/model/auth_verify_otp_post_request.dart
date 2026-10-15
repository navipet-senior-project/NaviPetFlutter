//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthVerifyOtpPostRequest {
  /// Returns a new [AuthVerifyOtpPostRequest] instance.
  AuthVerifyOtpPostRequest({
    required this.email,
    required this.code,
    required this.type,
  });

  String email;

  String code;

  /// 'recovery' verifies a password reset code (from /auth/forgot-password); 'register' verifies an email confirmation code (from /auth/register); 'email_change' verifies the code sent to a new address (from /auth/change-email).
  AuthVerifyOtpPostRequestTypeEnum type;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuthVerifyOtpPostRequest &&
    other.email == email &&
    other.code == code &&
    other.type == type;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (email.hashCode) +
    (code.hashCode) +
    (type.hashCode);

  @override
  String toString() => 'AuthVerifyOtpPostRequest[email=$email, code=$code, type=$type]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'email'] = this.email;
      json[r'code'] = this.code;
      json[r'type'] = this.type;
    return json;
  }

  /// Returns a new [AuthVerifyOtpPostRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthVerifyOtpPostRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AuthVerifyOtpPostRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AuthVerifyOtpPostRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthVerifyOtpPostRequest(
        email: mapValueOfType<String>(json, r'email')!,
        code: mapValueOfType<String>(json, r'code')!,
        type: AuthVerifyOtpPostRequestTypeEnum.fromJson(json[r'type'])!,
      );
    }
    return null;
  }

  static List<AuthVerifyOtpPostRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuthVerifyOtpPostRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthVerifyOtpPostRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthVerifyOtpPostRequest> mapFromJson(dynamic json) {
    final map = <String, AuthVerifyOtpPostRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthVerifyOtpPostRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthVerifyOtpPostRequest-objects as value to a dart map
  static Map<String, List<AuthVerifyOtpPostRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AuthVerifyOtpPostRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthVerifyOtpPostRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'email',
    'code',
    'type',
  };
}

/// 'recovery' verifies a password reset code (from /auth/forgot-password); 'register' verifies an email confirmation code (from /auth/register); 'email_change' verifies the code sent to a new address (from /auth/change-email).
class AuthVerifyOtpPostRequestTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const AuthVerifyOtpPostRequestTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const recovery = AuthVerifyOtpPostRequestTypeEnum._(r'recovery');
  static const register = AuthVerifyOtpPostRequestTypeEnum._(r'register');
  static const emailChange = AuthVerifyOtpPostRequestTypeEnum._(r'email_change');

  /// List of all possible values in this [enum][AuthVerifyOtpPostRequestTypeEnum].
  static const values = <AuthVerifyOtpPostRequestTypeEnum>[
    recovery,
    register,
    emailChange,
  ];

  static AuthVerifyOtpPostRequestTypeEnum? fromJson(dynamic value) => AuthVerifyOtpPostRequestTypeEnumTypeTransformer().decode(value);

  static List<AuthVerifyOtpPostRequestTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuthVerifyOtpPostRequestTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthVerifyOtpPostRequestTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuthVerifyOtpPostRequestTypeEnum] to String,
/// and [decode] dynamic data back to [AuthVerifyOtpPostRequestTypeEnum].
class AuthVerifyOtpPostRequestTypeEnumTypeTransformer {
  factory AuthVerifyOtpPostRequestTypeEnumTypeTransformer() => _instance ??= const AuthVerifyOtpPostRequestTypeEnumTypeTransformer._();

  const AuthVerifyOtpPostRequestTypeEnumTypeTransformer._();

  String encode(AuthVerifyOtpPostRequestTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuthVerifyOtpPostRequestTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuthVerifyOtpPostRequestTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'recovery': return AuthVerifyOtpPostRequestTypeEnum.recovery;
        case r'register': return AuthVerifyOtpPostRequestTypeEnum.register;
        case r'email_change': return AuthVerifyOtpPostRequestTypeEnum.emailChange;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuthVerifyOtpPostRequestTypeEnumTypeTransformer] instance.
  static AuthVerifyOtpPostRequestTypeEnumTypeTransformer? _instance;
}


