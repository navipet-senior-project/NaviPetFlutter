//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ClassesPost409ResponseError {
  /// Returns a new [ClassesPost409ResponseError] instance.
  ClassesPost409ResponseError({
    required this.code,
    required this.message,
    required this.requestId,
    this.conflicts = const [],
    this.existingClassId,
  });

  String code;

  String message;

  String requestId;

  List<ClassesPost409ResponseErrorConflictsInner> conflicts;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? existingClassId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassesPost409ResponseError &&
          other.code == code &&
          other.message == message &&
          other.requestId == requestId &&
          _deepEquality.equals(other.conflicts, conflicts) &&
          other.existingClassId == existingClassId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (code.hashCode) +
      (message.hashCode) +
      (requestId.hashCode) +
      (conflicts.hashCode) +
      (existingClassId == null ? 0 : existingClassId!.hashCode);

  @override
  String toString() =>
      'ClassesPost409ResponseError[code=$code, message=$message, requestId=$requestId, conflicts=$conflicts, existingClassId=$existingClassId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'code'] = this.code;
    json[r'message'] = this.message;
    json[r'requestId'] = this.requestId;
    json[r'conflicts'] = this.conflicts;
    if (this.existingClassId != null) {
      json[r'existingClassId'] = this.existingClassId;
    } else {
      json[r'existingClassId'] = null;
    }
    return json;
  }

  /// Returns a new [ClassesPost409ResponseError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ClassesPost409ResponseError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ClassesPost409ResponseError[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ClassesPost409ResponseError[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ClassesPost409ResponseError(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
        requestId: mapValueOfType<String>(json, r'requestId')!,
        conflicts: ClassesPost409ResponseErrorConflictsInner.listFromJson(
            json[r'conflicts']),
        existingClassId: mapValueOfType<String>(json, r'existingClassId'),
      );
    }
    return null;
  }

  static List<ClassesPost409ResponseError> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ClassesPost409ResponseError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ClassesPost409ResponseError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ClassesPost409ResponseError> mapFromJson(dynamic json) {
    final map = <String, ClassesPost409ResponseError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ClassesPost409ResponseError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ClassesPost409ResponseError-objects as value to a dart map
  static Map<String, List<ClassesPost409ResponseError>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ClassesPost409ResponseError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ClassesPost409ResponseError.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'message',
    'requestId',
  };
}
