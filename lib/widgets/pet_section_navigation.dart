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

void returnToPetHome(BuildContext context) {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  context.go(petSectionLocation(PetSectionTab.home, from));
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
          label: 'Back to Pet Home',
          excludeSemantics: true,
          child: SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              onPressed: () => returnToPetHome(context),
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

class PetSectionSideNavigation extends StatelessWidget {
  const PetSectionSideNavigation({super.key, required this.active});

  final PetSectionTab active;

  static const _tabs = [
    (PetSectionTab.pack, 'Pack', Icons.backpack_outlined),
    (PetSectionTab.shop, 'Shop', Icons.storefront_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Pet section',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (tab, label, icon) in _tabs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _tab(context, tab: tab, label: label, icon: icon),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required PetSectionTab tab,
    required String label,
    required IconData icon,
  }) {
    final selected = active == tab;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: ValueKey('pet-tab-$label'),
            customBorder: const CircleBorder(),
            onTap: () {
              final from = GoRouterState.of(
                context,
              ).uri.queryParameters['from'];
              context.pushReplacement(petSectionLocation(tab, from));
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: selected ? AppColors.yellowInk : Colors.white,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2600244E),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, size: 22, color: AppColors.petInk),
            ),
          ),
        ),
      ),
    );
  }
}
