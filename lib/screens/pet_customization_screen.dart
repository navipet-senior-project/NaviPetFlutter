import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/account_button.dart';

/// Pet Customization screen, cloned from the Figma "Pet cuztomization" frame
/// (node 17:3). Shows the dressed mascot, quick-action pills and a wardrobe
/// bento grid of outfits. The Menu tab in the shared bottom nav routes to the
/// Class Checklist (matching the prototype wiring).
class PetCustomizationScreen extends StatefulWidget {
  const PetCustomizationScreen({super.key});

  @override
  State<PetCustomizationScreen> createState() => _PetCustomizationScreenState();
}

class _Outfit {
  const _Outfit(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _PetCustomizationScreenState extends State<PetCustomizationScreen> {
  // Grid order matches the Figma layout: tee (active), cap, shades, hat.
  static const _outfits = [
    _Outfit('CSULB Tee', Icons.checkroom),
    _Outfit('Grad Cap', Icons.school_outlined),
    _Outfit('Shades', Icons.remove_red_eye_outlined),
    _Outfit('Beach Hat', Icons.beach_access_outlined),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    _mascot(),
                    const SizedBox(height: AppSpacing.xl),
                    _outfitsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const NaviBottomNav(active: NaviTab.pets),
    );
  }

  Widget _header() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(
                Icons.sentiment_satisfied_outlined,
                size: 20,
                color: AppColors.petInk,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Elbee',
                style: TextStyle(fontSize: 16, color: AppColors.petInk),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F4),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.diamond_outlined,
                      size: 14,
                      color: AppColors.blue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '\$1,250',
                      style: TextStyle(fontSize: 16, color: AppColors.petInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AccountButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mascot() {
    return Column(
      children: [
        Container(
          width: 192,
          height: 192,
          decoration: const BoxDecoration(
            color: Color(0xFFEEEEEE),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset('assets/images/shark_dressed.png', width: 176),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pill(label: 'Current Look', filled: true, onTap: () {}),
            const SizedBox(width: AppSpacing.sm),
            _pill(label: 'Save Outfit', filled: false, onTap: () {}),
          ],
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.yellow : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: filled ? null : Border.all(color: AppColors.petInk, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: filled ? AppColors.yellowInk : AppColors.petInk,
          ),
        ),
      ),
    );
  }

  Widget _outfitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'OUTFITS',
              style: TextStyle(fontSize: 16, color: AppColors.petInk),
            ),
            Text(
              'See All',
              style: TextStyle(fontSize: 16, color: AppColors.fieldIcon),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.lg,
          childAspectRatio: 1.02,
          children: [for (var i = 0; i < _outfits.length; i++) _outfitCard(i)],
        ),
      ],
    );
  }

  Widget _outfitCard(int index) {
    final outfit = _outfits[index];
    final active = _selected == index;
    return GestureDetector(
      onTap: () => setState(() => _selected = index),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.yellow : AppColors.cardBorder,
            width: active ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(outfit.icon, size: 34, color: AppColors.petInk),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    outfit.label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.petInk,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.petInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
