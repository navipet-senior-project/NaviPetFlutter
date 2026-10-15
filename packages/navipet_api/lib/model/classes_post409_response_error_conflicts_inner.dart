//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ClassesPost409ResponseErrorConflictsInner {
  /// Returns a new [ClassesPost409ResponseErrorConflictsInner] instance.
  ClassesPost409ResponseErrorConflictsInner({
    required this.existingClassId,
    required this.existingCourse,
    required this.day,
    required this.newTime,
    required this.existingTime,
    required this.location,
  });

  String existingClassId;

  String existingCourse;

  /// CSULB day label: M, Tu, W, Th, F, Sa, Su.
  String day;

  String newTime;

  String existingTime;

  String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassesPost409ResponseErrorConflictsInner &&
          other.existingClassId == existingClassId &&
          other.existingCourse == existingCourse &&
          other.day == day &&
          other.newTime == newTime &&
          other.existingTime == existingTime &&
          other.location == location;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (existingClassId.hashCode) +
      (existingCourse.hashCode) +
      (day.hashCode) +
      (newTime.hashCode) +
      (existingTime.hashCode) +
      (location.hashCode);

  @override
  String toString() =>
      'ClassesPost409ResponseErrorConflictsInner[existingClassId=$existingClassId, existingCourse=$existingCourse, day=$day, newTime=$newTime, existingTime=$existingTime, location=$location]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'existingClassId'] = this.existingClassId;
    json[r'existingCourse'] = this.existingCourse;
    json[r'day'] = this.day;
    json[r'newTime'] = this.newTime;
    json[r'existingTime'] = this.existingTime;
    json[r'location'] = this.location;
    return json;
  }

  /// Returns a new [ClassesPost409ResponseErrorConflictsInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ClassesPost409ResponseErrorConflictsInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ClassesPost409ResponseErrorConflictsInner[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ClassesPost409ResponseErrorConflictsInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ClassesPost409ResponseErrorConflictsInner(
        existingClassId: mapValueOfType<String>(json, r'existingClassId')!,
        existingCourse: mapValueOfType<String>(json, r'existingCourse')!,
        day: mapValueOfType<String>(json, r'day')!,
        newTime: mapValueOfType<String>(json, r'newTime')!,
        existingTime: mapValueOfType<String>(json, r'existingTime')!,
        location: mapValueOfType<String>(json, r'location')!,
      );
    }
    return null;
  }

  static List<ClassesPost409ResponseErrorConflictsInner> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ClassesPost409ResponseErrorConflictsInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ClassesPost409ResponseErrorConflictsInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ClassesPost409ResponseErrorConflictsInner> mapFromJson(
      dynamic json) {
    final map = <String, ClassesPost409ResponseErrorConflictsInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            ClassesPost409ResponseErrorConflictsInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ClassesPost409ResponseErrorConflictsInner-objects as value to a dart map
  static Map<String, List<ClassesPost409ResponseErrorConflictsInner>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ClassesPost409ResponseErrorConflictsInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ClassesPost409ResponseErrorConflictsInner.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'existingClassId',
    'existingCourse',
    'day',
    'newTime',
    'existingTime',
    'location',
  };
}
