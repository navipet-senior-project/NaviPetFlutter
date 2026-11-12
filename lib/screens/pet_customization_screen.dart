import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/pet_home.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_section_navigation.dart';

class PetOutfit {
  const PetOutfit(this.id, this.label, this.icon, this.price);
  final String id;
  final String label;
  final IconData icon;
  final int price;
}

const petOutfits = [
  PetOutfit('csulb_tee', 'CSULB Tee', Icons.checkroom, 20),
  PetOutfit('grad_cap', 'Grad Cap', Icons.school_outlined, 30),
  PetOutfit('shades', 'Shades', Icons.remove_red_eye_outlined, 15),
  PetOutfit('beach_hat', 'Beach Hat', Icons.beach_access_outlined, 25),
];

class PetCustomizationScreen extends StatefulWidget {
  const PetCustomizationScreen({super.key});

  @override
  State<PetCustomizationScreen> createState() => _PetCustomizationScreenState();
}

class _PetCustomizationScreenState extends State<PetCustomizationScreen> {
  String? _buyingId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PetSectionHeader(title: 'Shop', trailing: _gemBadge(state.points)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => _stage(
                        state.equippedOutfit,
                        height: math.min(
                          220.0,
                          math.max(176.0, constraints.maxHeight * .34),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Outfits',
                      style: TextStyle(
                        color: AppColors.petInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: petOutfits.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: largeText ? 252 : 178,
                      ),
                      itemBuilder: (context, index) => _outfitCard(
                        petOutfits[index],
                        owned: state.ownedOutfits.contains(
                          petOutfits[index].id,
                        ),
                        balance: state.points,
                        largeText: largeText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const PetSectionBottomNavigation(
        active: PetSectionTab.shop,
      ),
    );
  }

  Widget _stage(String? equippedId, {required double height}) {
    final outfit = petOutfits
        .where((item) => item.id == equippedId)
        .firstOrNull;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.petInk, width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 58,
            child: ColoredBox(color: Color(0xFFF3E2B0)),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      petImageFor(equippedId),
                      key: const ValueKey('shop-stage-elbee'),
                    ),
                  ),
                  Text(
                    'Elbee · ${outfit?.label ?? 'No outfit'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.petInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (outfit != null &&
              outfit.id != 'grad_cap' &&
              outfit.id != 'csulb_tee')
            Align(
              alignment: const Alignment(.55, .18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.yellow,
                child: Icon(outfit.icon, color: AppColors.petInk, size: 19),
              ),
            ),
        ],
      ),
    );
  }

  Widget _outfitCard(
    PetOutfit outfit, {
    required bool owned,
    required int balance,
    required bool largeText,
  }) {
    final shortfall = math.max(0, outfit.price - balance);
    final buying = _buyingId == outfit.id;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(outfit.icon, size: largeText ? 28 : 34, color: AppColors.petInk),
          Text(
            outfit.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.petInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(
            height: largeText ? 68 : 44,
            width: double.infinity,
            child: FilledButton(
              key: ValueKey('shop-${outfit.id}'),
              onPressed: owned
                  ? () => _openPack()
                  : buying || shortfall > 0
                  ? null
                  : () => _buy(outfit),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.petInk,
                disabledBackgroundColor: const Color(0xFFF2F4F7),
                disabledForegroundColor: AppColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: shortfall > 0 && !owned
                        ? const Color(0xFFD0D5DD)
                        : AppColors.petInk,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: buying
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      owned
                          ? 'In Pack'
                          : shortfall > 0
                          ? 'Need $shortfall more${largeText ? '\ngems' : ' gems'}'
                          : 'Buy ${outfit.price} gems',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: largeText ? 10 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gemBadge(int balance) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.petInk, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.diamond, color: AppColors.blue, size: 18),
        const SizedBox(width: 4),
        Text('$balance', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  void _openPack() {
    context.pushReplacement(
      petSectionLocation(
        PetSectionTab.pack,
        GoRouterState.of(context).uri.queryParameters['from'],
      ),
    );
  }

  Future<void> _buy(PetOutfit outfit) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = outfit.id);
    try {
      await context.read<AppState>().buyOutfit(outfit.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${outfit.label} added to your Pack.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not buy ${outfit.label}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }
}
