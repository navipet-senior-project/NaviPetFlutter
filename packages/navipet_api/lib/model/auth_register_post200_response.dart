//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthRegisterPost200Response {
  /// Returns a new [AuthRegisterPost200Response] instance.
  AuthRegisterPost200Response({
    required this.message,
    required this.otpRequired,
  });

  AuthRegisterPost200ResponseMessageEnum message;

  bool otpRequired;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AuthRegisterPost200Response &&
    other.message == message &&
    other.otpRequired == otpRequired;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (message.hashCode) +
    (otpRequired.hashCode);

  @override
  String toString() => 'AuthRegisterPost200Response[message=$message, otpRequired=$otpRequired]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'message'] = this.message;
      json[r'otp_required'] = this.otpRequired;
    return json;
  }

  /// Returns a new [AuthRegisterPost200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthRegisterPost200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AuthRegisterPost200Response[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AuthRegisterPost200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthRegisterPost200Response(
        message: AuthRegisterPost200ResponseMessageEnum.fromJson(json[r'message'])!,
        otpRequired: mapValueOfType<bool>(json, r'otp_required')!,
      );
    }
    return null;
  }

  static List<AuthRegisterPost200Response> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuthRegisterPost200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthRegisterPost200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthRegisterPost200Response> mapFromJson(dynamic json) {
    final map = <String, AuthRegisterPost200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthRegisterPost200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthRegisterPost200Response-objects as value to a dart map
  static Map<String, List<AuthRegisterPost200Response>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AuthRegisterPost200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthRegisterPost200Response.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'message',
    'otp_required',
  };
}


class AuthRegisterPost200ResponseMessageEnum {
  /// Instantiate a new enum with the provided [value].
  const AuthRegisterPost200ResponseMessageEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const verificationCodeSentPeriodCheckYourInboxPeriod = AuthRegisterPost200ResponseMessageEnum._(r'Verification code sent. Check your inbox.');

  /// List of all possible values in this [enum][AuthRegisterPost200ResponseMessageEnum].
  static const values = <AuthRegisterPost200ResponseMessageEnum>[
    verificationCodeSentPeriodCheckYourInboxPeriod,
  ];

  static AuthRegisterPost200ResponseMessageEnum? fromJson(dynamic value) => AuthRegisterPost200ResponseMessageEnumTypeTransformer().decode(value);

  static List<AuthRegisterPost200ResponseMessageEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AuthRegisterPost200ResponseMessageEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthRegisterPost200ResponseMessageEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuthRegisterPost200ResponseMessageEnum] to String,
/// and [decode] dynamic data back to [AuthRegisterPost200ResponseMessageEnum].
class AuthRegisterPost200ResponseMessageEnumTypeTransformer {
  factory AuthRegisterPost200ResponseMessageEnumTypeTransformer() => _instance ??= const AuthRegisterPost200ResponseMessageEnumTypeTransformer._();

  const AuthRegisterPost200ResponseMessageEnumTypeTransformer._();

  String encode(AuthRegisterPost200ResponseMessageEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuthRegisterPost200ResponseMessageEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuthRegisterPost200ResponseMessageEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'Verification code sent. Check your inbox.': return AuthRegisterPost200ResponseMessageEnum.verificationCodeSentPeriodCheckYourInboxPeriod;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuthRegisterPost200ResponseMessageEnumTypeTransformer] instance.
  static AuthRegisterPost200ResponseMessageEnumTypeTransformer? _instance;
}


