import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable pill search bar, ported from the RN `components/SearchBar.tsx`.
///
/// When [onPressed] is provided the field becomes a read-only button (the RN
/// component disables the input and forwards the press), which is how the Map
/// screen uses it to navigate to Search.
class SearchBarField extends StatelessWidget {
  const SearchBarField({
    super.key,
    this.placeholder = 'Search destination',
    this.onPressed,
    this.right,
  });

  final String placeholder;
  final VoidCallback? onPressed;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: onPressed == null
                ? Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.faint,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        placeholder,
                        style: const TextStyle(
                          color: AppColors.faint,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPressed,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.faint,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          placeholder,
                          style: const TextStyle(
                            color: AppColors.faint,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (right != null) ...[const SizedBox(width: AppSpacing.sm), right!],
        ],
      ),
    );
  }
}
