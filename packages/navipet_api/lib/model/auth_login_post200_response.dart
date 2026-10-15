//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthLoginPost200Response {
  /// Returns a new [AuthLoginPost200Response] instance.
  AuthLoginPost200Response({
    required this.accessToken,
    required this.refreshToken,
  });

  String accessToken;

  String refreshToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthLoginPost200Response &&
          other.accessToken == accessToken &&
          other.refreshToken == refreshToken;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accessToken.hashCode) + (refreshToken.hashCode);

  @override
  String toString() =>
      'AuthLoginPost200Response[accessToken=$accessToken, refreshToken=$refreshToken]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'access_token'] = this.accessToken;
    json[r'refresh_token'] = this.refreshToken;
    return json;
  }

  /// Returns a new [AuthLoginPost200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthLoginPost200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthLoginPost200Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthLoginPost200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthLoginPost200Response(
        accessToken: mapValueOfType<String>(json, r'access_token')!,
        refreshToken: mapValueOfType<String>(json, r'refresh_token')!,
      );
    }
    return null;
  }

  static List<AuthLoginPost200Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthLoginPost200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthLoginPost200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthLoginPost200Response> mapFromJson(dynamic json) {
    final map = <String, AuthLoginPost200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthLoginPost200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthLoginPost200Response-objects as value to a dart map
  static Map<String, List<AuthLoginPost200Response>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthLoginPost200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthLoginPost200Response.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'access_token',
    'refresh_token',
  };
}
