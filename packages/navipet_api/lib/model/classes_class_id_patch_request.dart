//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ClassesClassIdPatchRequest {
  /// Returns a new [ClassesClassIdPatchRequest] instance.
  ClassesClassIdPatchRequest({
    this.courseCode,
    this.courseName,
    this.building,
    this.room,
    this.weekdays = const [],
    this.isOnline,
    this.startTime,
    this.endTime,
    this.time,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? courseCode;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? courseName;

  /// A CSULB building name or code (e.g. \"VEC\" or \"Vivian Engineering Center\") is resolved against the campus dataset. Anything else (a street address, another campus, an off-campus site) is forward-geocoded with Mapbox instead. Either way the stored class gets a resolved display name plus latitude/longitude. Required for in-person classes. Optional for online classes, where it is stored as sent (possibly empty) and never resolved.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? building;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? room;

  /// ISO weekdays the class meets: 1 = Monday ... 7 = Sunday.
  List<int> weekdays;

  /// An online class has no physical location: no building is required and no coordinates are stored. A synchronous online class still occupies its time slot for conflict checks.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? isOnline;

  /// Local start time: 24-hour \"HH:MM\" / \"HH:MM:SS\", or 12-hour \"4:00 PM\" / \"4PM\". Omit when sending `time`.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? startTime;

  /// Local end time, same formats as `startTime`. Must be later than `startTime`. Omit when sending `time`.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? endTime;

  /// A CSULB schedule time range such as \"8-8:50AM\", \"12:30-3:15PM\", \"4-6:45PM\", or \"10:30AM-1:15PM\". AM/PM written once applies to both ends unless the range crosses noon (\"11-12:15PM\" is 11:00 AM-12:15 PM). Replaces `startTime` + `endTime`. \"NA/NA\" (no scheduled time) is rejected with 422.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? time;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ClassesClassIdPatchRequest &&
    other.courseCode == courseCode &&
    other.courseName == courseName &&
    other.building == building &&
    other.room == room &&
    _deepEquality.equals(other.weekdays, weekdays) &&
    other.isOnline == isOnline &&
    other.startTime == startTime &&
    other.endTime == endTime &&
    other.time == time;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (courseCode == null ? 0 : courseCode!.hashCode) +
    (courseName == null ? 0 : courseName!.hashCode) +
    (building == null ? 0 : building!.hashCode) +
    (room == null ? 0 : room!.hashCode) +
    (weekdays.hashCode) +
    (isOnline == null ? 0 : isOnline!.hashCode) +
    (startTime == null ? 0 : startTime!.hashCode) +
    (endTime == null ? 0 : endTime!.hashCode) +
    (time == null ? 0 : time!.hashCode);

  @override
  String toString() => 'ClassesClassIdPatchRequest[courseCode=$courseCode, courseName=$courseName, building=$building, room=$room, weekdays=$weekdays, isOnline=$isOnline, startTime=$startTime, endTime=$endTime, time=$time]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.courseCode != null) {
      json[r'courseCode'] = this.courseCode;
    } else {
      json[r'courseCode'] = null;
    }
    if (this.courseName != null) {
      json[r'courseName'] = this.courseName;
    } else {
      json[r'courseName'] = null;
    }
    if (this.building != null) {
      json[r'building'] = this.building;
    } else {
      json[r'building'] = null;
    }
    if (this.room != null) {
      json[r'room'] = this.room;
    } else {
      json[r'room'] = null;
    }
      json[r'weekdays'] = this.weekdays;
    if (this.isOnline != null) {
      json[r'isOnline'] = this.isOnline;
    } else {
      json[r'isOnline'] = null;
    }
    if (this.startTime != null) {
      json[r'startTime'] = this.startTime;
    } else {
      json[r'startTime'] = null;
    }
    if (this.endTime != null) {
      json[r'endTime'] = this.endTime;
    } else {
      json[r'endTime'] = null;
    }
    if (this.time != null) {
      json[r'time'] = this.time;
    } else {
      json[r'time'] = null;
    }
    return json;
  }

  /// Returns a new [ClassesClassIdPatchRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ClassesClassIdPatchRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ClassesClassIdPatchRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ClassesClassIdPatchRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ClassesClassIdPatchRequest(
        courseCode: mapValueOfType<String>(json, r'courseCode'),
        courseName: mapValueOfType<String>(json, r'courseName'),
        building: mapValueOfType<String>(json, r'building'),
        room: mapValueOfType<String>(json, r'room'),
        weekdays: json[r'weekdays'] is Iterable
            ? (json[r'weekdays'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        isOnline: mapValueOfType<bool>(json, r'isOnline'),
        startTime: mapValueOfType<String>(json, r'startTime'),
        endTime: mapValueOfType<String>(json, r'endTime'),
        time: mapValueOfType<String>(json, r'time'),
      );
    }
    return null;
  }

  static List<ClassesClassIdPatchRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ClassesClassIdPatchRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ClassesClassIdPatchRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ClassesClassIdPatchRequest> mapFromJson(dynamic json) {
    final map = <String, ClassesClassIdPatchRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ClassesClassIdPatchRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ClassesClassIdPatchRequest-objects as value to a dart map
  static Map<String, List<ClassesClassIdPatchRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ClassesClassIdPatchRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ClassesClassIdPatchRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

