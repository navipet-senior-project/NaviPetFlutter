//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMeGet200ResponseProfile {
  /// Returns a new [ProfilesMeGet200ResponseProfile] instance.
  ProfilesMeGet200ResponseProfile({
    required this.displayName,
    required this.email,
    required this.role,
    required this.avatarUrl,
  });

  String displayName;

  String? email;

  ProfilesMeGet200ResponseProfileRoleEnum? role;

  /// Temporary signed avatar URL, valid for about one hour. `null` when the avatar cannot be served; show a local placeholder instead.
  String? avatarUrl;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProfilesMeGet200ResponseProfile &&
    other.displayName == displayName &&
    other.email == email &&
    other.role == role &&
    other.avatarUrl == avatarUrl;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (displayName.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (role == null ? 0 : role!.hashCode) +
    (avatarUrl == null ? 0 : avatarUrl!.hashCode);

  @override
  String toString() => 'ProfilesMeGet200ResponseProfile[displayName=$displayName, email=$email, role=$role, avatarUrl=$avatarUrl]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'displayName'] = this.displayName;
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.role != null) {
      json[r'role'] = this.role;
    } else {
      json[r'role'] = null;
    }
    if (this.avatarUrl != null) {
      json[r'avatarUrl'] = this.avatarUrl;
    } else {
      json[r'avatarUrl'] = null;
    }
    return json;
  }

  /// Returns a new [ProfilesMeGet200ResponseProfile] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMeGet200ResponseProfile? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ProfilesMeGet200ResponseProfile[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ProfilesMeGet200ResponseProfile[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMeGet200ResponseProfile(
        displayName: mapValueOfType<String>(json, r'displayName')!,
        email: mapValueOfType<String>(json, r'email'),
        role: ProfilesMeGet200ResponseProfileRoleEnum.fromJson(json[r'role']),
        avatarUrl: mapValueOfType<String>(json, r'avatarUrl'),
      );
    }
    return null;
  }

  static List<ProfilesMeGet200ResponseProfile> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfilesMeGet200ResponseProfile>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeGet200ResponseProfile.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMeGet200ResponseProfile> mapFromJson(dynamic json) {
    final map = <String, ProfilesMeGet200ResponseProfile>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfilesMeGet200ResponseProfile.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMeGet200ResponseProfile-objects as value to a dart map
  static Map<String, List<ProfilesMeGet200ResponseProfile>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ProfilesMeGet200ResponseProfile>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfilesMeGet200ResponseProfile.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'displayName',
    'email',
    'role',
    'avatarUrl',
  };
}


class ProfilesMeGet200ResponseProfileRoleEnum {
  /// Instantiate a new enum with the provided [value].
  const ProfilesMeGet200ResponseProfileRoleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const student = ProfilesMeGet200ResponseProfileRoleEnum._(r'student');
  static const professor = ProfilesMeGet200ResponseProfileRoleEnum._(r'professor');

  /// List of all possible values in this [enum][ProfilesMeGet200ResponseProfileRoleEnum].
  static const values = <ProfilesMeGet200ResponseProfileRoleEnum>[
    student,
    professor,
  ];

  static ProfilesMeGet200ResponseProfileRoleEnum? fromJson(dynamic value) => ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer().decode(value);

  static List<ProfilesMeGet200ResponseProfileRoleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfilesMeGet200ResponseProfileRoleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMeGet200ResponseProfileRoleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ProfilesMeGet200ResponseProfileRoleEnum] to String,
/// and [decode] dynamic data back to [ProfilesMeGet200ResponseProfileRoleEnum].
class ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer {
  factory ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer() => _instance ??= const ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer._();

  const ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer._();

  String encode(ProfilesMeGet200ResponseProfileRoleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ProfilesMeGet200ResponseProfileRoleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ProfilesMeGet200ResponseProfileRoleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'student': return ProfilesMeGet200ResponseProfileRoleEnum.student;
        case r'professor': return ProfilesMeGet200ResponseProfileRoleEnum.professor;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer] instance.
  static ProfilesMeGet200ResponseProfileRoleEnumTypeTransformer? _instance;
}


