//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BuildingsBuildingCodeRoomsGet200Response {
  /// Returns a new [BuildingsBuildingCodeRoomsGet200Response] instance.
  BuildingsBuildingCodeRoomsGet200Response({
    required this.building,
    required this.query,
    this.results = const [],
  });

  BuildingsBuildingCodeRoomsGet200ResponseBuilding building;

  String query;

  List<AutocompleteGet200ResponseResultsInner> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingsBuildingCodeRoomsGet200Response &&
          other.building == building &&
          other.query == query &&
          _deepEquality.equals(other.results, results);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (building.hashCode) + (query.hashCode) + (results.hashCode);

  @override
  String toString() =>
      'BuildingsBuildingCodeRoomsGet200Response[building=$building, query=$query, results=$results]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'building'] = this.building;
    json[r'query'] = this.query;
    json[r'results'] = this.results;
    return json;
  }

  /// Returns a new [BuildingsBuildingCodeRoomsGet200Response] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BuildingsBuildingCodeRoomsGet200Response? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "BuildingsBuildingCodeRoomsGet200Response[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "BuildingsBuildingCodeRoomsGet200Response[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return BuildingsBuildingCodeRoomsGet200Response(
        building: BuildingsBuildingCodeRoomsGet200ResponseBuilding.fromJson(
            json[r'building'])!,
        query: mapValueOfType<String>(json, r'query')!,
        results: AutocompleteGet200ResponseResultsInner.listFromJson(
            json[r'results']),
      );
    }
    return null;
  }

  static List<BuildingsBuildingCodeRoomsGet200Response> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <BuildingsBuildingCodeRoomsGet200Response>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BuildingsBuildingCodeRoomsGet200Response.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BuildingsBuildingCodeRoomsGet200Response> mapFromJson(
      dynamic json) {
    final map = <String, BuildingsBuildingCodeRoomsGet200Response>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            BuildingsBuildingCodeRoomsGet200Response.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BuildingsBuildingCodeRoomsGet200Response-objects as value to a dart map
  static Map<String, List<BuildingsBuildingCodeRoomsGet200Response>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<BuildingsBuildingCodeRoomsGet200Response>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BuildingsBuildingCodeRoomsGet200Response.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'building',
    'query',
    'results',
  };
}
