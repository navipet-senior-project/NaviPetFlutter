//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RecentSearchesGet200ResponseRecentSearchesInner {
  /// Returns a new [RecentSearchesGet200ResponseRecentSearchesInner] instance.
  RecentSearchesGet200ResponseRecentSearchesInner({
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
    required this.searchedAt,
  });

  String id;

  RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum type;

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

  String searchedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RecentSearchesGet200ResponseRecentSearchesInner &&
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
    other.navigation == navigation &&
    other.searchedAt == searchedAt;

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
    (navigation == null ? 0 : navigation!.hashCode) +
    (searchedAt.hashCode);

  @override
  String toString() => 'RecentSearchesGet200ResponseRecentSearchesInner[id=$id, type=$type, title=$title, subtitle=$subtitle, source_=$source_, buildingCode=$buildingCode, roomNumber=$roomNumber, floorNumber=$floorNumber, external_=$external_, attribution=$attribution, distanceMeters=$distanceMeters, navigation=$navigation, searchedAt=$searchedAt]';

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
      json[r'searchedAt'] = this.searchedAt;
    return json;
  }

  /// Returns a new [RecentSearchesGet200ResponseRecentSearchesInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RecentSearchesGet200ResponseRecentSearchesInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RecentSearchesGet200ResponseRecentSearchesInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RecentSearchesGet200ResponseRecentSearchesInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RecentSearchesGet200ResponseRecentSearchesInner(
        id: mapValueOfType<String>(json, r'id')!,
        type: RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.fromJson(json[r'type'])!,
        title: mapValueOfType<String>(json, r'title')!,
        subtitle: mapValueOfType<String>(json, r'subtitle')!,
        source_: mapValueOfType<String>(json, r'source')!,
        buildingCode: mapValueOfType<String>(json, r'buildingCode'),
        roomNumber: mapValueOfType<String>(json, r'roomNumber'),
        floorNumber: mapValueOfType<String>(json, r'floorNumber'),
        external_: mapValueOfType<bool>(json, r'external'),
        attribution: mapValueOfType<String>(json, r'attribution'),
        distanceMeters: mapValueOfType<int>(json, r'distanceMeters'),
        navigation: AutocompleteGet200ResponseResultsInnerNavigation.fromJson(json[r'navigation']),
        searchedAt: mapValueOfType<String>(json, r'searchedAt')!,
      );
    }
    return null;
  }

  static List<RecentSearchesGet200ResponseRecentSearchesInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RecentSearchesGet200ResponseRecentSearchesInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RecentSearchesGet200ResponseRecentSearchesInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RecentSearchesGet200ResponseRecentSearchesInner> mapFromJson(dynamic json) {
    final map = <String, RecentSearchesGet200ResponseRecentSearchesInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RecentSearchesGet200ResponseRecentSearchesInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RecentSearchesGet200ResponseRecentSearchesInner-objects as value to a dart map
  static Map<String, List<RecentSearchesGet200ResponseRecentSearchesInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RecentSearchesGet200ResponseRecentSearchesInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RecentSearchesGet200ResponseRecentSearchesInner.listFromJson(entry.value, growable: growable,);
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
    'searchedAt',
  };
}


class RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const building = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'building');
  static const room = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'room');
  static const entrance = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'entrance');
  static const parking = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'parking');
  static const dining = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'dining');
  static const service = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'service');
  static const amenity = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'amenity');
  static const transit = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'transit');
  static const housing = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'housing');
  static const landmark = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'landmark');
  static const external_ = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum._(r'external');

  /// List of all possible values in this [enum][RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum].
  static const values = <RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum>[
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

  static RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum? fromJson(dynamic value) => RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer().decode(value);

  static List<RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum] to String,
/// and [decode] dynamic data back to [RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum].
class RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer {
  factory RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer() => _instance ??= const RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer._();

  const RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer._();

  String encode(RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'building': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.building;
        case r'room': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.room;
        case r'entrance': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.entrance;
        case r'parking': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.parking;
        case r'dining': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.dining;
        case r'service': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.service;
        case r'amenity': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.amenity;
        case r'transit': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.transit;
        case r'housing': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.housing;
        case r'landmark': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.landmark;
        case r'external': return RecentSearchesGet200ResponseRecentSearchesInnerTypeEnum.external_;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer] instance.
  static RecentSearchesGet200ResponseRecentSearchesInnerTypeEnumTypeTransformer? _instance;
}


