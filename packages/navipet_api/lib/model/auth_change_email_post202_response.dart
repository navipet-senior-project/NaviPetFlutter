//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthChangeEmailPost202Response {
  /// Returns a new [AuthChangeEmailPost202Response] instance.
  AuthChangeEmailPost202Response({
    required this.status,
  });

  AuthChangeEmailPost202ResponseStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthChangeEmailPost202Response && other.status == status;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (status.hashCode);

  @override
  String toString() => 'AuthChangeEmailPost202Response[status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AuthChangeEmailPost202Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthChangeEmailPost202Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthChangeEmailPost202Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthChangeEmailPost202Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthChangeEmailPost202Response(
        status:
            AuthChangeEmailPost202ResponseStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AuthChangeEmailPost202Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthChangeEmailPost202Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthChangeEmailPost202Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthChangeEmailPost202Response> mapFromJson(dynamic json) {
    final map = <String, AuthChangeEmailPost202Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthChangeEmailPost202Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthChangeEmailPost202Response-objects as value to a dart map
  static Map<String, List<AuthChangeEmailPost202Response>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthChangeEmailPost202Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthChangeEmailPost202Response.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
  };
}

class AuthChangeEmailPost202ResponseStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AuthChangeEmailPost202ResponseStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const verificationRequired =
      AuthChangeEmailPost202ResponseStatusEnum._(r'verification_required');

  /// List of all possible values in this [enum][AuthChangeEmailPost202ResponseStatusEnum].
  static const values = <AuthChangeEmailPost202ResponseStatusEnum>[
    verificationRequired,
  ];

  static AuthChangeEmailPost202ResponseStatusEnum? fromJson(dynamic value) =>
      AuthChangeEmailPost202ResponseStatusEnumTypeTransformer().decode(value);

  static List<AuthChangeEmailPost202ResponseStatusEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthChangeEmailPost202ResponseStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthChangeEmailPost202ResponseStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AuthChangeEmailPost202ResponseStatusEnum] to String,
/// and [decode] dynamic data back to [AuthChangeEmailPost202ResponseStatusEnum].
class AuthChangeEmailPost202ResponseStatusEnumTypeTransformer {
  factory AuthChangeEmailPost202ResponseStatusEnumTypeTransformer() =>
      _instance ??=
          const AuthChangeEmailPost202ResponseStatusEnumTypeTransformer._();

  const AuthChangeEmailPost202ResponseStatusEnumTypeTransformer._();

  String encode(AuthChangeEmailPost202ResponseStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AuthChangeEmailPost202ResponseStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AuthChangeEmailPost202ResponseStatusEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'verification_required':
          return AuthChangeEmailPost202ResponseStatusEnum.verificationRequired;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AuthChangeEmailPost202ResponseStatusEnumTypeTransformer] instance.
  static AuthChangeEmailPost202ResponseStatusEnumTypeTransformer? _instance;
}
