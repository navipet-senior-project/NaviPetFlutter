import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/pet_home.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_section_navigation.dart';
import 'pet_customization_screen.dart';

class PetPackScreen extends StatefulWidget {
  const PetPackScreen({super.key});

  @override
  State<PetPackScreen> createState() => _PetPackScreenState();
}

class _PetPackScreenState extends State<PetPackScreen> {
  String? _previewId;
  bool _wearing = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final owned = [
      for (final outfit in petOutfits)
        if (state.ownedOutfits.contains(outfit.id)) outfit,
    ];
    final previewId = _previewId ?? state.equippedOutfit;
    final preview = petOutfits
        .where((item) => item.id == previewId)
        .firstOrNull;
    final equipped = previewId != null && state.equippedOutfit == previewId;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PetSectionHeader(title: 'Pack', trailing: _gemBadge(state.points)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => _stage(
                        preview,
                        equipped: equipped,
                        height: math.min(
                          268.0,
                          math.max(190.0, constraints.maxHeight * .42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (largeText)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Outfits',
                            style: TextStyle(
                              color: AppColors.petInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${owned.length} owned · ${petOutfits.length} total',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Outfits',
                              style: TextStyle(
                                color: AppColors.petInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${owned.length} owned · ${petOutfits.length} total',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    if (owned.isEmpty)
                      _emptyPack()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: owned.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: largeText ? 220 : 132,
                        ),
                        itemBuilder: (context, index) {
                          final outfit = owned[index];
                          return _outfitCard(
                            outfit,
                            selected: outfit.id == previewId,
                            equipped: outfit.id == state.equippedOutfit,
                            largeText: largeText,
                            onTap: () => setState(() => _previewId = outfit.id),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionBar(
            hasOwned: owned.isNotEmpty,
            selected: preview,
            equipped: equipped,
            onWear: () => _wear(preview),
          ),
          const PetSectionBottomNavigation(active: PetSectionTab.pack),
        ],
      ),
    );
  }

  Widget _stage(
    PetOutfit? outfit, {
    required bool equipped,
    required double height,
  }) => SizedBox(
    height: height,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.petInk, width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 68,
            child: ColoredBox(color: const Color(0xFFF3E2B0)),
          ),
          Positioned(
            bottom: 18,
            width: 182,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.petInk, width: 2),
                borderRadius: const BorderRadius.all(Radius.elliptical(91, 20)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 40),
            child: Image.asset(
              petImageFor(outfit?.id),
              height: height - 76,
              fit: BoxFit.contain,
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
          Positioned(
            top: 10,
            left: 10,
            child: Semantics(
              liveRegion: true,
              label: equipped
                  ? 'Wearing ${outfit?.label ?? 'no outfit'}'
                  : 'Previewing ${outfit?.label ?? 'Elbee'}, not saved',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.petInk, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  equipped ? 'Wearing' : 'Previewing · not saved',
                  style: const TextStyle(
                    color: AppColors.petInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Reset preview to equipped outfit',
              onPressed: () => setState(() => _previewId = null),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.petInk,
                minimumSize: const Size(44, 44),
                side: const BorderSide(color: AppColors.petInk, width: 2),
              ),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _outfitCard(
    PetOutfit outfit, {
    required bool selected,
    required bool equipped,
    required bool largeText,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label:
        '${outfit.label}, owned${equipped ? ', equipped' : ''}'
        '${selected && !equipped ? ', previewing' : ''}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.cardBorder,
            width: selected ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? const [BoxShadow(color: AppColors.petInk, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  outfit.icon,
                  size: largeText ? 28 : 34,
                  color: AppColors.petInk,
                ),
                const SizedBox(height: 6),
                Text(
                  outfit.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.petInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(equipped ? 'Wearing' : 'Owned'),
              ],
            ),
            if (equipped)
              Positioned(
                top: 8,
                left: 8,
                child: _statusChip('Wearing', AppColors.petInk, Colors.white),
              )
            else if (selected)
              Positioned(
                top: 8,
                left: 8,
                child: _statusChip(
                  'Preview',
                  AppColors.accentSoft,
                  AppColors.petInk,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _emptyPack() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Image.asset('assets/images/elbee.png', height: 88),
        const SizedBox(height: 8),
        const Text('Your pack is empty. Find an outfit in the Shop.'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.pushReplacement(
            petSectionLocation(
              PetSectionTab.shop,
              GoRouterState.of(context).uri.queryParameters['from'],
            ),
          ),
          child: const Text('Open Shop'),
        ),
      ],
    ),
  );

  Widget _actionBar({
    required bool hasOwned,
    required PetOutfit? selected,
    required bool equipped,
    required VoidCallback onWear,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.cardBorder)),
    ),
    child: SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: !hasOwned || selected == null
            ? () => context.pushReplacement(
                petSectionLocation(
                  PetSectionTab.shop,
                  GoRouterState.of(context).uri.queryParameters['from'],
                ),
              )
            : equipped || _wearing
            ? null
            : onWear,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.petInk,
          disabledBackgroundColor: const Color(0xFFF2F4F7),
          disabledForegroundColor: AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.petInk, width: 2),
          ),
        ),
        child: Text(
          !hasOwned || selected == null
              ? 'Open Shop'
              : _wearing
              ? 'Saving…'
              : equipped
              ? 'Wearing ${selected.label}'
              : 'Wear ${selected.label}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );

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

  Widget _statusChip(String label, Color background, Color foreground) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Future<void> _wear(PetOutfit? outfit) async {
    if (outfit == null || _wearing) return;
    setState(() => _wearing = true);
    try {
      await context.read<AppState>().equipOutfit(outfit.id);
      if (mounted) setState(() => _previewId = null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not wear ${outfit.label}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _wearing = false);
    }
  }
}
