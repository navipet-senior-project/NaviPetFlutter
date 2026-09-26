import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// The three destinations of the shared bottom navigation bar, mirroring the
/// Figma "Bottom Navigation Bar" component (Menu / Location / Pets).
enum NaviTab { menu, location, pets }

/// Shared bottom navigation bar, cloned from the Figma prototype.
///
/// Three slots: a Menu (hamburger) button on the left routing to the Class
/// Checklist, a raised paw "Pets" floating action button in the centre routing
/// to Pet Customization, and a Location (pin) button on the right routing to
/// the Map. Used by the Map, Pet and Checklist screens so they share the same
/// navigation surface.
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
        context.go('/pet');
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconButton(context, tab: NaviTab.menu, icon: Icons.menu),
                _petsFab(context),
                _iconButton(
                  context,
                  tab: NaviTab.location,
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _iconButton(
    BuildContext context, {
    required NaviTab tab,
    required IconData icon,
  }) {
    final isActive = active == tab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goTo(context, tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.accentSoft : Colors.transparent,
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x66F5A623),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: isActive ? AppColors.petInk : AppColors.faint,
          ),
        ),
      ),
    );
  }

  Widget _petsFab(BuildContext context) {
    final isActive = active == NaviTab.pets;
    return GestureDetector(
      onTap: () => _goTo(context, NaviTab.pets),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentSoft : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x99002B5B),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.pets,
          size: 24,
          color: isActive ? AppColors.petInk : AppColors.faint,
        ),
      ),
    );
  }
}
