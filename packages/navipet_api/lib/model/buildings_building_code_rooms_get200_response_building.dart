//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BuildingsBuildingCodeRoomsGet200ResponseBuilding {
  /// Returns a new [BuildingsBuildingCodeRoomsGet200ResponseBuilding] instance.
  BuildingsBuildingCodeRoomsGet200ResponseBuilding({
    required this.id,
    required this.code,
    required this.name,
  });

  String id;

  String code;

  String name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BuildingsBuildingCodeRoomsGet200ResponseBuilding &&
    other.id == id &&
    other.code == code &&
    other.name == name;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (code.hashCode) +
    (name.hashCode);

  @override
  String toString() => 'BuildingsBuildingCodeRoomsGet200ResponseBuilding[id=$id, code=$code, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'code'] = this.code;
      json[r'name'] = this.name;
    return json;
  }

  /// Returns a new [BuildingsBuildingCodeRoomsGet200ResponseBuilding] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BuildingsBuildingCodeRoomsGet200ResponseBuilding? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "BuildingsBuildingCodeRoomsGet200ResponseBuilding[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "BuildingsBuildingCodeRoomsGet200ResponseBuilding[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return BuildingsBuildingCodeRoomsGet200ResponseBuilding(
        id: mapValueOfType<String>(json, r'id')!,
        code: mapValueOfType<String>(json, r'code')!,
        name: mapValueOfType<String>(json, r'name')!,
      );
    }
    return null;
  }

  static List<BuildingsBuildingCodeRoomsGet200ResponseBuilding> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BuildingsBuildingCodeRoomsGet200ResponseBuilding>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BuildingsBuildingCodeRoomsGet200ResponseBuilding.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BuildingsBuildingCodeRoomsGet200ResponseBuilding> mapFromJson(dynamic json) {
    final map = <String, BuildingsBuildingCodeRoomsGet200ResponseBuilding>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BuildingsBuildingCodeRoomsGet200ResponseBuilding.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BuildingsBuildingCodeRoomsGet200ResponseBuilding-objects as value to a dart map
  static Map<String, List<BuildingsBuildingCodeRoomsGet200ResponseBuilding>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BuildingsBuildingCodeRoomsGet200ResponseBuilding>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BuildingsBuildingCodeRoomsGet200ResponseBuilding.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'code',
    'name',
  };
}

