//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ClassResponse {
  /// Returns a new [ClassResponse] instance.
  ClassResponse({
    required this.id,
    required this.courseCode,
    required this.courseName,
    required this.building,
    required this.room,
    this.weekdays = const [],
    required this.isOnline,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
  });

  String id;

  String courseCode;

  String courseName;

  /// A CSULB building name or code (e.g. \"VEC\" or \"Vivian Engineering Center\") is resolved against the campus dataset. Anything else (a street address, another campus, an off-campus site) is forward-geocoded with Mapbox instead. Either way the stored class gets a resolved display name plus latitude/longitude. Required for in-person classes. Optional for online classes, where it is stored as sent (possibly empty) and never resolved.
  String building;

  String room;

  /// ISO weekdays the class meets: 1 = Monday ... 7 = Sunday.
  List<int> weekdays;

  /// An online class has no physical location: no building is required and no coordinates are stored. A synchronous online class still occupies its time slot for conflict checks.
  bool isOnline;

  /// 24-hour local time as stored, \"HH:MM:SS\".
  String startTime;

  /// 24-hour local time as stored, \"HH:MM:SS\".
  String endTime;

  String createdAt;

  String updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassResponse &&
          other.id == id &&
          other.courseCode == courseCode &&
          other.courseName == courseName &&
          other.building == building &&
          other.room == room &&
          _deepEquality.equals(other.weekdays, weekdays) &&
          other.isOnline == isOnline &&
          other.startTime == startTime &&
          other.endTime == endTime &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id.hashCode) +
      (courseCode.hashCode) +
      (courseName.hashCode) +
      (building.hashCode) +
      (room.hashCode) +
      (weekdays.hashCode) +
      (isOnline.hashCode) +
      (startTime.hashCode) +
      (endTime.hashCode) +
      (createdAt.hashCode) +
      (updatedAt.hashCode);

  @override
  String toString() =>
      'ClassResponse[id=$id, courseCode=$courseCode, courseName=$courseName, building=$building, room=$room, weekdays=$weekdays, isOnline=$isOnline, startTime=$startTime, endTime=$endTime, createdAt=$createdAt, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'id'] = this.id;
    json[r'courseCode'] = this.courseCode;
    json[r'courseName'] = this.courseName;
    json[r'building'] = this.building;
    json[r'room'] = this.room;
    json[r'weekdays'] = this.weekdays;
    json[r'isOnline'] = this.isOnline;
    json[r'startTime'] = this.startTime;
    json[r'endTime'] = this.endTime;
    json[r'createdAt'] = this.createdAt;
    json[r'updatedAt'] = this.updatedAt;
    return json;
  }

  /// Returns a new [ClassResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ClassResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ClassResponse[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ClassResponse[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ClassResponse(
        id: mapValueOfType<String>(json, r'id')!,
        courseCode: mapValueOfType<String>(json, r'courseCode')!,
        courseName: mapValueOfType<String>(json, r'courseName')!,
        building: mapValueOfType<String>(json, r'building')!,
        room: mapValueOfType<String>(json, r'room')!,
        weekdays: json[r'weekdays'] is Iterable
            ? (json[r'weekdays'] as Iterable)
                .cast<int>()
                .toList(growable: false)
            : const [],
        isOnline: mapValueOfType<bool>(json, r'isOnline')!,
        startTime: mapValueOfType<String>(json, r'startTime')!,
        endTime: mapValueOfType<String>(json, r'endTime')!,
        createdAt: mapValueOfType<String>(json, r'createdAt')!,
        updatedAt: mapValueOfType<String>(json, r'updatedAt')!,
      );
    }
    return null;
  }

  static List<ClassResponse> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ClassResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ClassResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ClassResponse> mapFromJson(dynamic json) {
    final map = <String, ClassResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ClassResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ClassResponse-objects as value to a dart map
  static Map<String, List<ClassResponse>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ClassResponse>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ClassResponse.listFromJson(
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
    'courseCode',
    'courseName',
    'building',
    'room',
    'weekdays',
    'isOnline',
    'startTime',
    'endTime',
    'createdAt',
    'updatedAt',
  };
}
