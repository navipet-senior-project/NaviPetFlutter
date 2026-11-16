import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// The three destinations of the shared bottom navigation bar, mirroring the
/// Figma "Bottom Navigation Bar" component (Menu / Location / Pets).
enum NaviTab { menu, location, pets }

/// Shared bottom navigation bar, cloned from the Figma prototype.
///
/// Three labelled slots: Calendar on the left routing to the class calendar,
/// Pet in the centre routing to Pet Home, and Locations on the right
/// routing to the Map. Used by the Map, Pet and Calendar screens so they share
/// the same navigation surface.
class NaviBottomNav extends StatelessWidget {
  const NaviBottomNav({super.key, required this.active});

  final NaviTab active;

  void _goTo(BuildContext context, NaviTab tab) {
    if (tab == active) return;
    switch (tab) {
      case NaviTab.menu:
        context.go('/checklist');
      case NaviTab.location:
        context.go('/map');
      case NaviTab.pets:
        final returnTo = active == NaviTab.menu ? '/checklist' : '/map';
        context.push('/pet?from=$returnTo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: 64 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The bar itself.
          Container(
            height: 64 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Color(0xFFE2E2E2))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14002A4E), // 0,36,78 @ 0.08
                  offset: Offset(0, -4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                _item(
                  context,
                  tab: NaviTab.menu,
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                ),
                _item(
                  context,
                  tab: NaviTab.pets,
                  icon: Icons.pets,
                  label: 'Pet',
                ),
                _item(
                  context,
                  tab: NaviTab.location,
                  icon: Icons.location_on_outlined,
                  label: 'Locations',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One destination: an icon in a circle with its label underneath. The
  /// active tab gets a glowing navy ring and a bold label, so it never relies
  /// on colour alone.
  Widget _item(
    BuildContext context, {
    required NaviTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = active == tab;
    final foreground = isActive ? AppColors.navy : AppColors.muted;
    return Expanded(
      child: Semantics(
        key: ValueKey('nav-$label'),
        button: true,
        selected: isActive,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _goTo(context, tab),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.accentSoft : Colors.transparent,
                  border: isActive
                      ? Border.all(color: AppColors.navy, width: 2)
                      : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, size: 20, color: foreground),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The bar is a fixed 64px; a larger label overflows it.
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.5),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: foreground,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
