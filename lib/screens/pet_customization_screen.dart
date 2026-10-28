import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

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
  const _Outfit(this.id, this.label, this.icon, this.price);
  final String id;
  final String label;
  final IconData icon;
  final int price;
}

class _PetCustomizationScreenState extends State<PetCustomizationScreen> {
  // Grid order matches the Figma layout: tee (active), cap, shades, hat.
  static const _outfits = [
    _Outfit('csulb_tee', 'CSULB Tee', Icons.checkroom, 20),
    _Outfit('grad_cap', 'Grad Cap', Icons.school_outlined, 30),
    _Outfit('shades', 'Shades', Icons.remove_red_eye_outlined, 15),
    _Outfit('beach_hat', 'Beach Hat', Icons.beach_access_outlined, 25),
  ];

  bool _buying = false;

  Future<void> _selectOutfit(_Outfit outfit) async {
    final state = context.read<AppState>();
    if (_buying) return;
    setState(() => _buying = true);
    try {
      final owned = state.ownedOutfits.contains(outfit.id);
      if (!owned) await state.buyOutfit(outfit.id);
      await state.equipOutfit(outfit.id);
      if (mounted && !owned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${outfit.label} purchased for ${outfit.price} points.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select ${outfit.label}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F4),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: const [
                Icon(Icons.diamond_outlined, size: 14, color: AppColors.blue),
                SizedBox(width: 4),
                Text(
                  '${context.watch<AppState>().points} points',
                  style: TextStyle(fontSize: 16, color: AppColors.petInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mascot() {
    final equippedId = context.watch<AppState>().equippedOutfit;
    final equipped = _outfits.where((outfit) => outfit.id == equippedId);
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/images/shark_dressed.png', width: 176),
              if (equipped.isNotEmpty)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: CircleAvatar(
                    backgroundColor: AppColors.yellow,
                    child: Icon(equipped.first.icon, color: AppColors.petInk),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          equipped.isEmpty
              ? 'Choose an outfit from the store'
              : 'Wearing ${equipped.first.label}',
        ),
      ],
    );
  }

  Widget _outfitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PET STORE · OUTFITS',
          style: TextStyle(fontSize: 16, color: AppColors.petInk),
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
    final state = context.watch<AppState>();
    final owned = state.ownedOutfits.contains(outfit.id);
    final active = state.equippedOutfit == outfit.id;
    return GestureDetector(
      onTap: () {
        _selectOutfit(outfit);
      },
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
                  Text(
                    owned ? 'Owned · Tap to equip' : '${outfit.price} points',
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
