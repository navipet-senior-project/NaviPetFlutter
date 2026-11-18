import 'dart:async';
import 'dart:math' as math;

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
import '../widgets/bottom_nav_bar.dart';
import 'pet_customization_screen.dart';

class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  bool _refreshFailed = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

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
  Widget build(BuildContext context) => petTextScaleCap(_build);

  Widget _build(BuildContext context) {
    final state = context.watch<AppState>();
    final loading = state.classesBusy && state.classes.isEmpty;
    // Do not show a made-up 0 before the live balance has arrived.
    final walletLoading =
        state.hasPetBackend && !state.petLoaded && state.petError == null;
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
            final scaler = MediaQuery.textScalerOf(context);
            final hudCompact = compact || scaler.scale(1) > 1.5;
            final hudTop = MediaQuery.paddingOf(context).top + 8;
            // shortcut: estimated two-row HUD height (56 row, 8 gap, level
            // chip), measure it instead if the HUD gains rows.
            final hudBottom = hudCompact
                ? hudTop + 64 + math.max(56.0, 28 + scaler.scale(15) * 1.5)
                : 0.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _RoomPainter(hudBottom, _now)),
                ),
                Positioned(
                  right: 16,
                  top:
                      constraints.maxHeight * .15 +
                      math.max(
                        0.0,
                        hudBottom + 12 - constraints.maxHeight * .20,
                      ),
                  child: _roomWallControls(_now),
                ),
                Positioned(
                  top: hudTop,
                  left: 16,
                  right: 16,
                  child: _hud(
                    PetLevel(completions),
                    gems: loading || walletLoading ? null : state.points,
                    compact: hudCompact,
                  ),
                ),
                Positioned(
                  // Bottom-anchored so Elbee's feet stay on the rug whatever
                  // the bubble height or text scale.
                  bottom:
                      constraints.maxHeight -
                      petRugRect(constraints.biggest).center.dy,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 230),
                        child: _messageBubble(message),
                      ),
                      const SizedBox(height: 8),
                      _mascot(state.equippedOutfit, compact: compact),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _todayCard(loading: loading, error: error, next: next),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: PetSectionSideNavigation(active: PetSectionTab.home),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const NaviBottomNav(active: NaviTab.pets),
    );
  }

  Widget _hud(PetLevel level, {required int? gems, required bool compact}) {
    final wallet = Row(
      mainAxisSize: MainAxisSize.min,
      children: [_gems(gems), const SizedBox(width: 8), const AccountButton()],
    );
    if (compact) {
      return Column(
        children: [
          Row(children: [const Spacer(), wallet]),
          const SizedBox(height: 8),
          _levelChip(level),
        ],
      );
    }
    return Row(
      children: [
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
        'verified class completions to the next level',
    value: '${level.current} of ${PetLevel.perLevel}',
    child: Container(
      key: const ValueKey('pet-level'),
      constraints: const BoxConstraints(minHeight: 56),
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
      constraints: const BoxConstraints(minHeight: 56),
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
    final outfit = visiblePetOutfits(
      context.read<AppState>(),
    ).where((item) => item.id == outfitId).firstOrNull;
    final hasCustomArt = outfitId == 'grad_cap' || outfitId == 'csulb_tee';
    return Semantics(
      button: true,
      label: outfit == null
          ? 'Elbee the shark'
          : 'Elbee the shark, wearing ${outfit.label}',
      hint: 'Tap to refresh gems',
      child: GestureDetector(
        onTap: () => context.read<AppState>().refreshPoints(),
        child: SizedBox(
          key: const ValueKey('pet-mascot'),
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

  Widget _roomWallControls(DateTime now) => SizedBox(
    width: 112,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF25384B),
            border: Border.all(color: const Color(0xFF17283A), width: 2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Color(0x3300244E), offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Text(
                _digitalTime(now),
                key: const ValueKey('pet-digital-clock'),
                style: const TextStyle(
                  color: Color(0xFFFFE6A8),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _timeOfDayLabel(now),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: "Open today's daily tasks in the calendar",
          child: Material(
            color: const Color(0xFFFFF8E9),
            elevation: 3,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: const ValueKey('pet-calendar-shortcut'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.push('/checklist?focus=daily'),
              child: Container(
                width: 100,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.petInk, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD66D5E),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_weekdayShort(now.weekday)}  ${now.day}',
                      style: const TextStyle(
                        color: AppColors.petInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.blue,
                      size: 22,
                    ),
                    const Text(
                      "TODAY'S TASKS",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.petInk,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  String _digitalTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} '
        '${time.hour < 12 ? 'AM' : 'PM'}';
  }

  String _timeOfDayLabel(DateTime time) => switch (time.hour) {
    >= 5 && < 12 => 'MORNING',
    >= 12 && < 17 => 'AFTERNOON',
    >= 17 && < 21 => 'EVENING',
    _ => 'NIGHT',
  };

  String _weekdayShort(int weekday) =>
      const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];

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
      return _card(
        Row(
          children: [
            const Icon(Icons.event_available_outlined, color: AppColors.petInk),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No upcoming classes this week.',
                style: TextStyle(
                  color: AppColors.petInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final course = next.course;
    return _card(
      _infoWithAction(
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showClassDetailSheet(context, course),
          child: Row(
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
            ],
          ),
        ),
        _petButton(label: 'Guide', onPressed: _openGuide),
      ),
      onTap: () => showClassDetailSheet(context, course),
      semanticLabel: 'Open ${course.courseCode} class details',
    );
  }

  // Stacks the action under the text at large text scales, where a
  // side-by-side row leaves the text only a few pixels wide.
  Widget _infoWithAction(Widget info, Widget action) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.5
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [info, const SizedBox(height: 8), action],
        )
      : Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 8),
            action,
          ],
        );

  Widget _card(Widget child, {VoidCallback? onTap, String? semanticLabel}) =>
      Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            key: const ValueKey('pet-today-card'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.soft,
            ),
            child: child,
          ),
        ),
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

/// The rug Elbee stands on. Shared by the painter and the mascot anchor.
Rect petRugRect(Size room) => Rect.fromCenter(
  center: Offset(room.width / 2, room.height * .68 + 54),
  width: room.width * .7,
  height: 56,
);

class _RoomPainter extends CustomPainter {
  const _RoomPainter(this.hudBottom, this.now);

  /// Bottom of a two-row HUD, or 0. The wall art moves down to clear it.
  final double hudBottom;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final hour = now.hour;
    final night = hour < 5 || hour >= 21;
    final evening = hour >= 17 && hour < 21;
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: night
            ? const [Color(0xFF29394F), Color(0xFF52606C)]
            : evening
            ? const [Color(0xFFE6C7B8), Color(0xFFF1DAB8)]
            : const [Color(0xFFDDF1EF), Color(0xFFF2E9D6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * .68));
    final floor = Paint()
      ..color = night
          ? const Color(0xFF9B8059)
          : evening
          ? const Color(0xFFE4C18F)
          : const Color(0xFFF3E2B0);
    final trim = Paint()
      ..color = night ? const Color(0xFF80694D) : const Color(0xFFE3CF98);
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

    final drop = math.max(0.0, hudBottom + 12 - size.height * .20);
    final window = Rect.fromLTWH(
      size.width * .08,
      size.height * .20 + drop,
      116,
      136,
    );
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
    final sky = night
        ? const [Color(0xFF101D3A), Color(0xFF263B62)]
        : evening
        ? const [Color(0xFFF2A06E), Color(0xFF806B9C)]
        : hour < 12
        ? const [Color(0xFFFFD7A0), Color(0xFF9BCBEA)]
        : const [Color(0xFF80C7ED), Color(0xFFD3F0FF)];
    canvas.drawPath(
      windowPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sky,
        ).createShader(window),
    );
    if (night) {
      final moonPaint = Paint()..color = const Color(0xFFFFE7A6);
      canvas.drawCircle(
        Offset(window.right - 27, window.top + 34),
        10,
        moonPaint,
      );
      canvas.drawCircle(
        Offset(window.right - 22, window.top + 30),
        10,
        Paint()..color = sky.first,
      );
      for (final point in [
        Offset(window.left + 25, window.top + 29),
        Offset(window.left + 45, window.top + 16),
        Offset(window.left + 82, window.top + 48),
      ]) {
        canvas.drawCircle(point, 1.5, Paint()..color = Colors.white);
      }
    } else {
      canvas.drawCircle(
        Offset(window.left + 28, window.top + 35),
        12,
        Paint()
          ..color = evening ? const Color(0xFFFFC17B) : const Color(0xFFFFE796),
      );
    }
    if (!night) {
      final beam = Path()
        ..moveTo(window.left + 30, window.bottom - 3)
        ..lineTo(window.left - 14, floorTop)
        ..lineTo(window.right + 42, floorTop)
        ..lineTo(window.right - 17, window.bottom - 3)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: evening
                    ? const [Color(0x24FFC17B), Color(0x08FFC17B)]
                    : const [Color(0x20FFF2B2), Color(0x08FFF2B2)],
              ).createShader(
                Rect.fromLTRB(
                  window.left - 14,
                  window.bottom,
                  window.right + 42,
                  floorTop,
                ),
              ),
      );
    }
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

    final rug = petRugRect(size);
    canvas.drawOval(rug, white);
    canvas.drawOval(rug, navy);
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) =>
      oldDelegate.hudBottom != hudBottom ||
      oldDelegate.now.hour != now.hour ||
      oldDelegate.now.minute != now.minute;
}
