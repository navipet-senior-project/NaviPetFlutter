//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesMePatchRequest {
  /// Returns a new [ProfilesMePatchRequest] instance.
  ProfilesMePatchRequest({
    this.displayName,
    this.role,
    this.avatarUploadId,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? displayName;

  ProfilesMePatchRequestRoleEnum? role;

  /// The uploadId returned by POST /profiles/me/avatar. Supplying it commits that temporary avatar when the profile is saved.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? avatarUploadId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilesMePatchRequest &&
          other.displayName == displayName &&
          other.role == role &&
          other.avatarUploadId == avatarUploadId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (displayName == null ? 0 : displayName!.hashCode) +
      (role == null ? 0 : role!.hashCode) +
      (avatarUploadId == null ? 0 : avatarUploadId!.hashCode);

  @override
  String toString() =>
      'ProfilesMePatchRequest[displayName=$displayName, role=$role, avatarUploadId=$avatarUploadId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.displayName != null) {
      json[r'displayName'] = this.displayName;
    } else {
      json[r'displayName'] = null;
    }
    if (this.role != null) {
      json[r'role'] = this.role;
    } else {
      json[r'role'] = null;
    }
    if (this.avatarUploadId != null) {
      json[r'avatarUploadId'] = this.avatarUploadId;
    } else {
      json[r'avatarUploadId'] = null;
    }
    return json;
  }

  /// Returns a new [ProfilesMePatchRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfilesMePatchRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ProfilesMePatchRequest[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ProfilesMePatchRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfilesMePatchRequest(
        displayName: mapValueOfType<String>(json, r'displayName'),
        role: ProfilesMePatchRequestRoleEnum.fromJson(json[r'role']),
        avatarUploadId: mapValueOfType<String>(json, r'avatarUploadId'),
      );
    }
    return null;
  }

  static List<ProfilesMePatchRequest> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ProfilesMePatchRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMePatchRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfilesMePatchRequest> mapFromJson(dynamic json) {
    final map = <String, ProfilesMePatchRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfilesMePatchRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfilesMePatchRequest-objects as value to a dart map
  static Map<String, List<ProfilesMePatchRequest>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ProfilesMePatchRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfilesMePatchRequest.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}

class ProfilesMePatchRequestRoleEnum {
  /// Instantiate a new enum with the provided [value].
  const ProfilesMePatchRequestRoleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const student = ProfilesMePatchRequestRoleEnum._(r'student');
  static const professor = ProfilesMePatchRequestRoleEnum._(r'professor');

  /// List of all possible values in this [enum][ProfilesMePatchRequestRoleEnum].
  static const values = <ProfilesMePatchRequestRoleEnum>[
    student,
    professor,
  ];

  static ProfilesMePatchRequestRoleEnum? fromJson(dynamic value) =>
      ProfilesMePatchRequestRoleEnumTypeTransformer().decode(value);

  static List<ProfilesMePatchRequestRoleEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ProfilesMePatchRequestRoleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfilesMePatchRequestRoleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ProfilesMePatchRequestRoleEnum] to String,
/// and [decode] dynamic data back to [ProfilesMePatchRequestRoleEnum].
class ProfilesMePatchRequestRoleEnumTypeTransformer {
  factory ProfilesMePatchRequestRoleEnumTypeTransformer() =>
      _instance ??= const ProfilesMePatchRequestRoleEnumTypeTransformer._();

  const ProfilesMePatchRequestRoleEnumTypeTransformer._();

  String encode(ProfilesMePatchRequestRoleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ProfilesMePatchRequestRoleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ProfilesMePatchRequestRoleEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'student':
          return ProfilesMePatchRequestRoleEnum.student;
        case r'professor':
          return ProfilesMePatchRequestRoleEnum.professor;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ProfilesMePatchRequestRoleEnumTypeTransformer] instance.
  static ProfilesMePatchRequestRoleEnumTypeTransformer? _instance;
}
