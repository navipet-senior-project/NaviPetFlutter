import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/navigation_flow_controller.dart';
import '../data/pet_home.dart';
import '../theme/app_theme.dart';
import '../widgets/account_button.dart';
import '../widgets/class_detail_sheet.dart';
import '../widgets/elbee_sheet.dart';
import '../widgets/pet_section_navigation.dart';
import 'pet_customization_screen.dart';

class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  bool _refreshFailed = false;

  Future<void> _refresh() async {
    setState(() => _refreshFailed = false);
    try {
      await context.read<AppState>().refreshClasses();
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    }
  }

  void _openGuide() {
    final router = GoRouter.of(context);
    showElbeeSheet(
      context,
      flow: context.read<NavigationFlowController>(),
      onPlaceSelected: () => router.go('/map'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final loading = state.classesBusy && state.classes.isEmpty;
    final error =
        state.classesError ??
        (_refreshFailed
            ? 'Could not reach NaviPet. Check your connection and try again.'
            : null);
    final next = upcomingClasses(state.classes, DateTime.now()).firstOrNull;
    final completions = state.classes.fold<int>(
      0,
      (sum, course) => sum + state.completionCountFor(course.id),
    );
    final message = petMessage(
      loading: loading,
      failed: error != null,
      missions: state.dailyTasks(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFDDF1EF),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 640;
            return Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _RoomPainter()),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 16,
                  right: 16,
                  child: _hud(
                    PetLevel(completions),
                    gems: loading ? null : state.points,
                    compact:
                        compact ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.5,
                  ),
                ),
                Positioned(
                  top: constraints.maxHeight * (compact ? .34 : .36),
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mascot(state.equippedOutfit, compact: compact),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 230),
                        child: _messageBubble(message),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _todayCard(loading: loading, error: error, next: next),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const PetSectionBottomNavigation(
        active: PetSectionTab.home,
      ),
    );
  }

  Widget _hud(PetLevel level, {required int? gems, required bool compact}) {
    final back = Semantics(
      button: true,
      label: 'Back to Navipet',
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          key: const ValueKey('pet-back'),
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
    );
    final wallet = Row(
      mainAxisSize: MainAxisSize.min,
      children: [_gems(gems), const SizedBox(width: 8), const AccountButton()],
    );
    if (compact) {
      return Column(
        children: [
          Row(children: [back, const Spacer(), wallet]),
          const SizedBox(height: 8),
          _levelChip(level),
        ],
      );
    }
    return Row(
      children: [
        back,
        const SizedBox(width: 8),
        Expanded(child: _levelChip(level)),
        const SizedBox(width: 8),
        wallet,
      ],
    );
  }

  Widget _levelChip(PetLevel level) => Semantics(
    container: true,
    label:
        'Level ${level.level}, ${level.current} of ${PetLevel.perLevel} '
        'verified missions to the next level',
    value: '${level.current} of ${PetLevel.perLevel}',
    child: Container(
      height: MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 72 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _hudDecoration(),
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Elbee · Lv ${level.level}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.petInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${level.current} / ${PetLevel.perLevel}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 8,
                color: AppColors.yellow,
                backgroundColor: const Color(0xFFEAECF0),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _gems(int? gems) => Semantics(
    label: gems == null ? 'Gems loading' : '$gems gems',
    child: Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: _hudDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, size: 18, color: AppColors.blue),
          const SizedBox(width: 4),
          if (gems == null)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              '$gems',
              style: const TextStyle(
                color: AppColors.petInk,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    ),
  );

  BoxDecoration _hudDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppColors.petInk, width: 2),
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x2200244E), offset: Offset(0, 3)),
    ],
  );

  Widget _mascot(String? outfitId, {required bool compact}) {
    final outfit = petOutfits.where((item) => item.id == outfitId).firstOrNull;
    final hasCustomArt = outfitId == 'grad_cap' || outfitId == 'csulb_tee';
    return Semantics(
      image: true,
      label: outfit == null
          ? 'Elbee the shark'
          : 'Elbee the shark, wearing ${outfit.label}',
      child: SizedBox(
        height: compact ? 150 : 184,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              petImageFor(outfitId),
              height: compact ? 150 : 184,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            if (outfit != null && !hasCustomArt)
              Positioned(
                right: 6,
                bottom: 6,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.yellow,
                  child: Icon(outfit.icon, color: AppColors.petInk, size: 19),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(String message) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.petInk, width: 2),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.petInk, fontSize: 13),
    ),
  );

  Widget _todayCard({
    required bool loading,
    required String? error,
    required UpcomingClass? next,
  }) {
    if (loading) {
      return _card(
        Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Checking your schedule...')),
          ],
        ),
      );
    }
    if (error != null) {
      return _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Couldn't load your classes. $error",
              style: const TextStyle(color: AppColors.danger),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            ),
            if (next != null)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(next.course.courseCode),
                  subtitle: Text(next.course.locationLabel),
                  onTap: () => showClassDetailSheet(context, next.course),
                  trailing: _petButton(label: 'Guide', onPressed: _openGuide),
                ),
              ),
          ],
        ),
      );
    }
    if (next == null) {
      final hasClasses = context.read<AppState>().classes.isNotEmpty;
      return _card(
        Row(
          children: [
            const Icon(Icons.event_available_outlined, color: AppColors.petInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasClasses
                    ? 'No upcoming classes this week.'
                    : 'Add a class to start exploring together.',
                style: const TextStyle(
                  color: AppColors.petInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/checklist'),
              child: Text(hasClasses ? 'Calendar' : 'Add class'),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final course = next.course;
    return _card(
      Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.petInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showClassDetailSheet(context, course),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${upcomingDayLabel(next.start, now)} · ${course.startLabel}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${course.courseCode} · ${course.locationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.petInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _petButton(label: 'Guide', onPressed: _openGuide),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.cardBorder),
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.soft,
    ),
    child: child,
  );

  Widget _petButton({required String label, required VoidCallback onPressed}) =>
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.petInk,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.petInk, width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xFFDDF1EF);
    final floor = Paint()..color = const Color(0xFFF3E2B0);
    final trim = Paint()..color = const Color(0xFFE3CF98);
    final glass = Paint()..color = const Color(0xFFBFE3F7);
    final white = Paint()..color = Colors.white;
    final navy = Paint()
      ..color = AppColors.petInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(Offset.zero & size, wall);
    final floorTop = size.height * .68;
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop),
      floor,
    );
    canvas.drawRect(Rect.fromLTWH(0, floorTop, size.width, 6), trim);

    final window = Rect.fromLTWH(size.width * .08, size.height * .20, 116, 136);
    final windowPath = Path()
      ..moveTo(window.left, window.bottom)
      ..lineTo(window.left, window.top + 55)
      ..quadraticBezierTo(window.left, window.top, window.left + 58, window.top)
      ..quadraticBezierTo(
        window.right,
        window.top,
        window.right,
        window.top + 55,
      )
      ..lineTo(window.right, window.bottom)
      ..close();
    canvas.drawPath(windowPath, glass);
    canvas.drawPath(
      windowPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawLine(
      Offset(window.center.dx, window.top + 4),
      Offset(window.center.dx, window.bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      Offset(window.left + 3, window.top + 68),
      Offset(window.right - 3, window.top + 68),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4,
    );
    canvas.drawPath(windowPath, navy);

    final rug = Rect.fromCenter(
      center: Offset(size.width / 2, floorTop + 54),
      width: size.width * .7,
      height: 56,
    );
    canvas.drawOval(rug, white);
    canvas.drawOval(rug, navy);

    final sign = Rect.fromLTWH(size.width * .64, size.height * .25, 82, 54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sign, const Radius.circular(6)),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sign, const Radius.circular(6)),
      navy,
    );
    final text = TextPainter(
      text: const TextSpan(
        text: 'CAMPUS',
        style: TextStyle(
          color: AppColors.petInk,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(sign.center.dx - text.width / 2, sign.top + 14));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sign.left + 14, sign.top + 37, 54, 4),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.yellow,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) => false;
}
