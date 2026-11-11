import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ar_mode_icon.dart';

class OutdoorArEntryButton extends StatelessWidget {
  const OutdoorArEntryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: 'Outdoor AR unavailable',
      hint: 'Shows why outdoor AR guidance is not available yet',
      button: true,
      child: Tooltip(
        message: 'Outdoor AR unavailable',
        child: Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 112,
              height: 56,
              child: Center(
                child: ExcludeSemantics(
                  child: ArModeIcon(color: AppColors.navy, size: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showOutdoorArUnavailableDialog(
  BuildContext context,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Outdoor AR unavailable'),
    content: const Text(
      'Outdoor AR guidance is not available yet. Your walking route stays active on the map.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Return to map'),
      ),
    ],
  ),
);
