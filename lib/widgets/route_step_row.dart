import 'package:flutter/material.dart';

import '../data/navigation_models.dart';
import '../theme/app_theme.dart';

class RouteStepRow extends StatelessWidget {
  const RouteStepRow({
    super.key,
    required this.step,
    required this.index,
    this.isDestination = false,
  });

  final NavigationStep step;
  final int index;
  final bool isDestination;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${index + 1}. ${step.instruction}. ${step.distanceLabel}.',
    child: ExcludeSemantics(
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: isDestination
              ? AppColors.accentSoft
              : AppColors.screenBg,
          child: Icon(
            _icon(step),
            size: 20,
            color: isDestination ? AppColors.amberInk : AppColors.navy,
          ),
        ),
        title: Text(
          step.instruction,
          style: const TextStyle(color: AppColors.ink),
        ),
        trailing: Text(
          step.distanceLabel,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    ),
  );

  static IconData _icon(NavigationStep step) {
    if (step.maneuverType == 'arrive') return Icons.flag_outlined;
    if (step.maneuverType == 'depart') return Icons.my_location;
    return switch (step.maneuverModifier) {
      'left' || 'sharp left' || 'slight left' => Icons.turn_left_rounded,
      'right' || 'sharp right' || 'slight right' => Icons.turn_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => Icons.straight_rounded,
    };
  }
}
