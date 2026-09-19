import 'package:flutter/material.dart';

import '../data/campus_place.dart';
import '../theme/app_theme.dart';

class CampusSearchResultTile extends StatelessWidget {
  const CampusSearchResultTile({
    super.key,
    required this.place,
    required this.onTap,
    this.enabled = true,
  });

  final CampusPlace place;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      _typeLabel(place.type),
      if (place.buildingCode != null) place.buildingCode!,
      if (place.roomNumber != null) 'Room ${place.roomNumber}',
      if (place.floorNumber != null) 'Floor ${place.floorNumber}',
      if (place.distanceMeters != null) _distanceLabel(place.distanceMeters!),
    ];

    return ListTile(
      enabled: enabled,
      onTap: onTap,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: CircleAvatar(
        backgroundColor: AppColors.accentSoft,
        child: Icon(
          _icon(place.type),
          key: ValueKey('campus-result-icon-${place.type.name}'),
          color: AppColors.amberInk,
        ),
      ),
      title: Text(
        place.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            meta.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.faint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.north_west, size: 18, color: AppColors.faint),
    );
  }

  static String _typeLabel(CampusDestinationType type) => switch (type) {
    CampusDestinationType.building => 'Building',
    CampusDestinationType.room => 'Room',
    CampusDestinationType.entrance => 'Entrance',
    CampusDestinationType.parking => 'Parking',
    CampusDestinationType.dining => 'Dining',
    CampusDestinationType.service => 'Service',
    CampusDestinationType.amenity => 'Amenity',
    CampusDestinationType.transit => 'Transit',
    CampusDestinationType.housing => 'Housing',
    CampusDestinationType.landmark => 'Landmark',
    CampusDestinationType.external => 'External',
  };

  static IconData _icon(CampusDestinationType type) => switch (type) {
    CampusDestinationType.building => Icons.business_outlined,
    CampusDestinationType.room => Icons.meeting_room_outlined,
    CampusDestinationType.entrance => Icons.sensor_door_outlined,
    CampusDestinationType.parking => Icons.local_parking,
    CampusDestinationType.dining => Icons.restaurant_outlined,
    CampusDestinationType.service => Icons.support_agent_outlined,
    CampusDestinationType.amenity => Icons.accessible_outlined,
    CampusDestinationType.transit => Icons.directions_bus_outlined,
    CampusDestinationType.housing => Icons.home_outlined,
    CampusDestinationType.landmark => Icons.place_outlined,
    CampusDestinationType.external => Icons.public,
  };

  static String _distanceLabel(int meters) {
    final miles = meters / 1609.344;
    if (miles < 0.1) return '${(meters * 3.28084).ceil()} ft';
    return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
  }
}
