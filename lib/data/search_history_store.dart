import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'navigation_models.dart';

class SearchHistoryStore {
  static const _storageKey = 'recent_mapbox_destinations_v1';
  static const maxItems = 3;

  Future<List<NaviDestination>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const [];
    return raw.map((value) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final typeName = json['type'] as String?;
      final type = typeName == null
          ? null
          : CampusDestinationType.values
                .where((value) => value.name == typeName)
                .firstOrNull;
      return NaviDestination(
        id: json['id'] as String?,
        type: type,
        name: json['name'] as String,
        address: json['address'] as String,
        coordinate: NavigationCoordinate(
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
        ),
        buildingCode: json['buildingCode'] as String?,
        roomNumber: json['roomNumber'] as String?,
        floorNumber: json['floorNumber'] as String?,
        indoorDestinationId: json['indoorDestinationId'] as String?,
        external: json['external'] == true,
        attribution: json['attribution'] as String?,
        isBuildingAlternative: json['isBuildingAlternative'] == true,
      );
    }).toList();
  }

  Future<List<NaviDestination>> add(NaviDestination destination) async {
    final current = await load();
    final updated = [
      destination,
      ...current.where((item) => !_sameDestination(item, destination)),
    ].take(maxItems).toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      updated
          .map(
            (item) => jsonEncode({
              if (item.id != null) 'id': item.id,
              if (item.type != null) 'type': item.type!.name,
              'name': item.name,
              'address': item.address,
              'latitude': item.coordinate.latitude,
              'longitude': item.coordinate.longitude,
              if (item.buildingCode != null) 'buildingCode': item.buildingCode,
              if (item.roomNumber != null) 'roomNumber': item.roomNumber,
              if (item.floorNumber != null) 'floorNumber': item.floorNumber,
              if (item.indoorDestinationId != null)
                'indoorDestinationId': item.indoorDestinationId,
              if (item.external) 'external': true,
              if (item.attribution != null) 'attribution': item.attribution,
              if (item.isBuildingAlternative) 'isBuildingAlternative': true,
            }),
          )
          .toList(),
    );
    return updated;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  bool _sameDestination(NaviDestination left, NaviDestination right) {
    if (left.id != null && right.id != null) return left.id == right.id;
    return left.name == right.name && left.address == right.address;
  }
}
