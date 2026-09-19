import 'package:flutter/material.dart';

import '../data/navigation_flow_state.dart';
import '../data/navigation_models.dart';
import '../data/travel_mode.dart';
import '../theme/app_theme.dart';
import 'route_step_row.dart';
import 'travel_mode_selector.dart';

/// Collapsed: the summary and the primary action.
/// Expanded: the same summary plus the ordered step list.
class RoutePreviewSheet extends StatelessWidget {
  const RoutePreviewSheet({
    super.key,
    required this.destination,
    required this.origin,
    required this.plan,
    required this.expanded,
    required this.onPrimary,
    required this.onToggleSteps,
    required this.onModeChanged,
    required this.onSelectRoute,
    required this.onEditOrigin,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final RoutePlan plan;
  final bool expanded;
  final VoidCallback onPrimary;
  final VoidCallback onToggleSteps;
  final ValueChanged<TravelMode> onModeChanged;
  final ValueChanged<int> onSelectRoute;
  final VoidCallback onEditOrigin;

  @override
  Widget build(BuildContext context) {
    final route = plan.selected;
    final primaryLabel = origin.canStartGuidance
        ? 'Start route'
        : 'Preview route';

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.durationLabel,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        route.distanceLabel,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        destination.name,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onEditOrigin,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.swap_vert, size: 16),
                        label: Text(
                          'From ${origin.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TravelModeSelector(selected: plan.mode, onChanged: onModeChanged),
            for (final warning in plan.warnings) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onToggleSteps,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: AppColors.inputBorder),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(expanded ? 'Hide steps' : 'Steps'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(primaryLabel),
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1, color: AppColors.line),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: route.steps.length,
                  itemBuilder: (context, index) => RouteStepRow(
                    step: route.steps[index],
                    index: index,
                    isDestination: index == route.steps.length - 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
