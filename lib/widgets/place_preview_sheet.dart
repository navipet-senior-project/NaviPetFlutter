import 'package:flutter/material.dart';

import '../data/campus_place.dart';
import '../data/navigation_flow_state.dart';
import '../theme/app_theme.dart';

/// Bottom card describing the selected place. It never starts navigation —
/// the user must choose Directions.
class PlacePreviewSheet extends StatelessWidget {
  const PlacePreviewSheet({
    super.key,
    required this.state,
    required this.onDirections,
    required this.onClose,
  });

  final FlowPlacePreview state;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final place = state.place;
    final subtitleParts = <String>[
      place.subtitle,
      if (place.floorNumber != null) 'Floor ${place.floorNumber}',
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Close place details',
                  button: true,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              subtitleParts.join(' · '),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  _typeLabel(place.type),
                  style: const TextStyle(
                    color: AppColors.amberInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!state.routable) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      "We don't have a map pin for this place yet.",
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: state.routable ? onDirections : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Directions'),
              ),
            ),
          ],
        ),
      ),
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
    CampusDestinationType.external => 'Off campus',
  };
}
