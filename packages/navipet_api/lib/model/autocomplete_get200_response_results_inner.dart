//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AutocompleteGet200ResponseResultsInner {
  /// Returns a new [AutocompleteGet200ResponseResultsInner] instance.
  AutocompleteGet200ResponseResultsInner({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.source_,
    this.buildingCode,
    this.roomNumber,
    this.floorNumber,
    this.external_,
    this.attribution,
    this.distanceMeters,
    this.navigation,
  });

  String id;

  AutocompleteGet200ResponseResultsInnerTypeEnum type;

  String title;

  String subtitle;

  String source_;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? buildingCode;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? roomNumber;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? floorNumber;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? external_;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? attribution;

  /// Minimum value: 0
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? distanceMeters;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  AutocompleteGet200ResponseResultsInnerNavigation? navigation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteGet200ResponseResultsInner &&
          other.id == id &&
          other.type == type &&
          other.title == title &&
          other.subtitle == subtitle &&
          other.source_ == source_ &&
          other.buildingCode == buildingCode &&
          other.roomNumber == roomNumber &&
          other.floorNumber == floorNumber &&
          other.external_ == external_ &&
          other.attribution == attribution &&
          other.distanceMeters == distanceMeters &&
          other.navigation == navigation;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id.hashCode) +
      (type.hashCode) +
      (title.hashCode) +
      (subtitle.hashCode) +
      (source_.hashCode) +
      (buildingCode == null ? 0 : buildingCode!.hashCode) +
      (roomNumber == null ? 0 : roomNumber!.hashCode) +
      (floorNumber == null ? 0 : floorNumber!.hashCode) +
      (external_ == null ? 0 : external_!.hashCode) +
      (attribution == null ? 0 : attribution!.hashCode) +
      (distanceMeters == null ? 0 : distanceMeters!.hashCode) +
      (navigation == null ? 0 : navigation!.hashCode);

  @override
  String toString() =>
      'AutocompleteGet200ResponseResultsInner[id=$id, type=$type, title=$title, subtitle=$subtitle, source_=$source_, buildingCode=$buildingCode, roomNumber=$roomNumber, floorNumber=$floorNumber, external_=$external_, attribution=$attribution, distanceMeters=$distanceMeters, navigation=$navigation]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'id'] = this.id;
    json[r'type'] = this.type;
    json[r'title'] = this.title;
    json[r'subtitle'] = this.subtitle;
    json[r'source'] = this.source_;
    if (this.buildingCode != null) {
      json[r'buildingCode'] = this.buildingCode;
    } else {
      json[r'buildingCode'] = null;
    }
    if (this.roomNumber != null) {
      json[r'roomNumber'] = this.roomNumber;
    } else {
      json[r'roomNumber'] = null;
    }
    if (this.floorNumber != null) {
      json[r'floorNumber'] = this.floorNumber;
    } else {
      json[r'floorNumber'] = null;
    }
    if (this.external_ != null) {
      json[r'external'] = this.external_;
    } else {
      json[r'external'] = null;
    }
    if (this.attribution != null) {
      json[r'attribution'] = this.attribution;
    } else {
      json[r'attribution'] = null;
    }
    if (this.distanceMeters != null) {
      json[r'distanceMeters'] = this.distanceMeters;
    } else {
      json[r'distanceMeters'] = null;
    }
    if (this.navigation != null) {
      json[r'navigation'] = this.navigation;
    } else {
      json[r'navigation'] = null;
    }
    return json;
  }

  /// Returns a new [AutocompleteGet200ResponseResultsInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AutocompleteGet200ResponseResultsInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AutocompleteGet200ResponseResultsInner[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AutocompleteGet200ResponseResultsInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AutocompleteGet200ResponseResultsInner(
        id: mapValueOfType<String>(json, r'id')!,
        type: AutocompleteGet200ResponseResultsInnerTypeEnum.fromJson(
            json[r'type'])!,
        title: mapValueOfType<String>(json, r'title')!,
        subtitle: mapValueOfType<String>(json, r'subtitle')!,
        source_: mapValueOfType<String>(json, r'source')!,
        buildingCode: mapValueOfType<String>(json, r'buildingCode'),
        roomNumber: mapValueOfType<String>(json, r'roomNumber'),
        floorNumber: mapValueOfType<String>(json, r'floorNumber'),
        external_: mapValueOfType<bool>(json, r'external'),
        attribution: mapValueOfType<String>(json, r'attribution'),
        distanceMeters: mapValueOfType<int>(json, r'distanceMeters'),
        navigation: AutocompleteGet200ResponseResultsInnerNavigation.fromJson(
            json[r'navigation']),
      );
    }
    return null;
  }

  static List<AutocompleteGet200ResponseResultsInner> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AutocompleteGet200ResponseResultsInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AutocompleteGet200ResponseResultsInner> mapFromJson(
      dynamic json) {
    final map = <String, AutocompleteGet200ResponseResultsInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value =
            AutocompleteGet200ResponseResultsInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AutocompleteGet200ResponseResultsInner-objects as value to a dart map
  static Map<String, List<AutocompleteGet200ResponseResultsInner>>
      mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AutocompleteGet200ResponseResultsInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AutocompleteGet200ResponseResultsInner.listFromJson(
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
    'type',
    'title',
    'subtitle',
    'source',
  };
}

class AutocompleteGet200ResponseResultsInnerTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const AutocompleteGet200ResponseResultsInnerTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const building =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'building');
  static const room = AutocompleteGet200ResponseResultsInnerTypeEnum._(r'room');
  static const entrance =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'entrance');
  static const parking =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'parking');
  static const dining =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'dining');
  static const service =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'service');
  static const amenity =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'amenity');
  static const transit =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'transit');
  static const housing =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'housing');
  static const landmark =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'landmark');
  static const external_ =
      AutocompleteGet200ResponseResultsInnerTypeEnum._(r'external');

  /// List of all possible values in this [enum][AutocompleteGet200ResponseResultsInnerTypeEnum].
  static const values = <AutocompleteGet200ResponseResultsInnerTypeEnum>[
    building,
    room,
    entrance,
    parking,
    dining,
    service,
    amenity,
    transit,
    housing,
    landmark,
    external_,
  ];

  static AutocompleteGet200ResponseResultsInnerTypeEnum? fromJson(
          dynamic value) =>
      AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer()
          .decode(value);

  static List<AutocompleteGet200ResponseResultsInnerTypeEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AutocompleteGet200ResponseResultsInnerTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            AutocompleteGet200ResponseResultsInnerTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AutocompleteGet200ResponseResultsInnerTypeEnum] to String,
/// and [decode] dynamic data back to [AutocompleteGet200ResponseResultsInnerTypeEnum].
class AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer {
  factory AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer() =>
      _instance ??=
          const AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer
              ._();

  const AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer._();

  String encode(AutocompleteGet200ResponseResultsInnerTypeEnum data) =>
      data.value;

  /// Decodes a [dynamic value][data] to a AutocompleteGet200ResponseResultsInnerTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AutocompleteGet200ResponseResultsInnerTypeEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'building':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.building;
        case r'room':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.room;
        case r'entrance':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.entrance;
        case r'parking':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.parking;
        case r'dining':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.dining;
        case r'service':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.service;
        case r'amenity':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.amenity;
        case r'transit':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.transit;
        case r'housing':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.housing;
        case r'landmark':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.landmark;
        case r'external':
          return AutocompleteGet200ResponseResultsInnerTypeEnum.external_;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer] instance.
  static AutocompleteGet200ResponseResultsInnerTypeEnumTypeTransformer?
      _instance;
}
