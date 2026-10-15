//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthMeGet200ResponseUser {
  /// Returns a new [AuthMeGet200ResponseUser] instance.
  AuthMeGet200ResponseUser({
    required this.id,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  String id;

  String email;

  AuthMeGet200ResponseUserStatusEnum status;

  String createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthMeGet200ResponseUser &&
          other.id == id &&
          other.email == email &&
          other.status == status &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id.hashCode) +
      (email.hashCode) +
      (status.hashCode) +
      (createdAt.hashCode);

  @override
  String toString() =>
      'AuthMeGet200ResponseUser[id=$id, email=$email, status=$status, createdAt=$createdAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'id'] = this.id;
    json[r'email'] = this.email;
    json[r'status'] = this.status;
    json[r'createdAt'] = this.createdAt;
    return json;
  }

  /// Returns a new [AuthMeGet200ResponseUser] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthMeGet200ResponseUser? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthMeGet200ResponseUser[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthMeGet200ResponseUser[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthMeGet200ResponseUser(
        id: mapValueOfType<String>(json, r'id')!,
        email: mapValueOfType<String>(json, r'email')!,
        status: AuthMeGet200ResponseUserStatusEnum.fromJson(json[r'status'])!,
        createdAt: mapValueOfType<String>(json, r'createdAt')!,
      );
    }
    return null;
  }

  static List<AuthMeGet200ResponseUser> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthMeGet200ResponseUser>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthMeGet200ResponseUser.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthMeGet200ResponseUser> mapFromJson(dynamic json) {
    final map = <String, AuthMeGet200ResponseUser>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthMeGet200ResponseUser.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthMeGet200ResponseUser-objects as value to a dart map
  static Map<String, List<AuthMeGet200ResponseUser>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthMeGet200ResponseUser>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthMeGet200ResponseUser.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'email',
    'status',
    'createdAt',
  };
}

class AuthMeGet200ResponseUserStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AuthMeGet200ResponseUserStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const ACTIVE = AuthMeGet200ResponseUserStatusEnum._(r'ACTIVE');
  static const DISABLED = AuthMeGet200ResponseUserStatusEnum._(r'DISABLED');

  /// List of all possible values in this [enum][AuthMeGet200ResponseUserStatusEnum].
  static const values = <AuthMeGet200ResponseUserStatusEnum>[
    ACTIVE,
    DISABLED,
  ];

  static AuthMeGet200ResponseUserStatusEnum? fromJson(dynamic value) =>
      AuthMeGet200ResponseUserStatusEnumTypeTransformer().decode(value);

  static List<AuthMeGet200ResponseUserStatusEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthMeGet200ResponseUserStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthMeGet200ResponseUserStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuthMeGet200ResponseUserStatusEnum] to String,
/// and [decode] dynamic data back to [AuthMeGet200ResponseUserStatusEnum].
class AuthMeGet200ResponseUserStatusEnumTypeTransformer {
  factory AuthMeGet200ResponseUserStatusEnumTypeTransformer() =>
      _instance ??= const AuthMeGet200ResponseUserStatusEnumTypeTransformer._();

  const AuthMeGet200ResponseUserStatusEnumTypeTransformer._();

  String encode(AuthMeGet200ResponseUserStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuthMeGet200ResponseUserStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuthMeGet200ResponseUserStatusEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'ACTIVE':
          return AuthMeGet200ResponseUserStatusEnum.ACTIVE;
        case r'DISABLED':
          return AuthMeGet200ResponseUserStatusEnum.DISABLED;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuthMeGet200ResponseUserStatusEnumTypeTransformer] instance.
  static AuthMeGet200ResponseUserStatusEnumTypeTransformer? _instance;
}
