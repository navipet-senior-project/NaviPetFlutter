import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

enum PetSectionTab { home, pack, shop, quests }

String petSectionLocation(PetSectionTab tab, String? returnTo) {
  final path = switch (tab) {
    PetSectionTab.home => '/pet',
    PetSectionTab.pack => '/pet/pack',
    PetSectionTab.shop => '/pet/shop',
    PetSectionTab.quests => '/pet/quests',
  };
  if (returnTo != '/map' && returnTo != '/checklist') return path;
  return Uri(path: path, queryParameters: {'from': returnTo}).toString();
}

void leavePetSection(BuildContext context) {
  final returnTo = GoRouterState.of(context).uri.queryParameters['from'];
  context.go(returnTo == '/checklist' ? '/checklist' : '/map');
}

/// Pet layouts fit text up to 2x; beyond that the fixed HUD and tabs overflow.
Widget petTextScaleCap(WidgetBuilder builder) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2,
      child: Builder(builder: builder),
    );

class PetSectionHeader extends StatelessWidget {
  const PetSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Back to Navipet',
          excludeSemantics: true,
          child: SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              onPressed: () => leavePetSection(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.petInk,
                side: const BorderSide(color: AppColors.petInk, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.chevron_left, size: 26),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // Shrinks instead of truncating a large-text title to one letter.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.petInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class PetSectionBottomNavigation extends StatelessWidget {
  const PetSectionBottomNavigation({
    super.key,
    required this.active,
  });

  final PetSectionTab active;

  static const _tabs = [
    (PetSectionTab.home, 'Home', Icons.home_outlined),
    (PetSectionTab.pack, 'Pack', Icons.backpack_outlined),
    (PetSectionTab.shop, 'Shop', Icons.storefront_outlined),
    (PetSectionTab.quests, 'Quests', Icons.fact_check_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Pet section',
      child: Container(
        height: (largeText ? 84 : 68) + bottomInset,
        padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.petInk, width: 2)),
        ),
        child: Row(
          children: [
            for (final (tab, label, icon) in _tabs)
              Expanded(
                child: _tab(
                  context,
                  tab: tab,
                  label: label,
                  icon: icon,
                  largeText: largeText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required PetSectionTab tab,
    required String label,
    required IconData icon,
    required bool largeText,
  }) {
    final selected = active == tab;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: ValueKey('pet-tab-$label'),
        borderRadius: BorderRadius.circular(18),
        onTap: selected
            ? null
            : () {
                final from = GoRouterState.of(
                  context,
                ).uri.queryParameters['from'];
                context.pushReplacement(petSectionLocation(tab, from));
              },
        child: SizedBox(
          height: largeText ? 76 : 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.yellow : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 22, color: AppColors.petInk),
                  ),
                  // Shrinks instead of wrapping a large-text label mid-word.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.petInk,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
