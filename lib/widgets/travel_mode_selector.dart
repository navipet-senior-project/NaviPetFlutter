import 'package:flutter/material.dart';

import '../data/travel_mode.dart';
import '../theme/app_theme.dart';

/// Chip row over the enabled travel modes. Only walking is enabled today;
/// adding a mode is a change to `enabledTravelModes`, not to this widget.
class TravelModeSelector extends StatelessWidget {
  const TravelModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TravelMode selected;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    children: [
      for (final mode in enabledTravelModes)
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: ChoiceChip(
            selected: mode == selected,
            onSelected: (_) => onChanged(mode),
            avatar: Icon(_icon(mode), size: 18),
            label: Text(mode.label),
            labelStyle: TextStyle(
              color: mode == selected ? AppColors.navy : AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.accentSoft,
            shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
          ),
        ),
    ],
  );

  static IconData _icon(TravelMode mode) => switch (mode) {
    TravelMode.walking => Icons.directions_walk_rounded,
    TravelMode.accessible => Icons.accessible_forward,
    TravelMode.shuttle => Icons.directions_bus_outlined,
    TravelMode.cycling => Icons.directions_bike_outlined,
  };
}
