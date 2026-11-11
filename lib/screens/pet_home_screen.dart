import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../data/navigation_flow_controller.dart';
import '../data/pet_home.dart';
import '../theme/app_theme.dart';
import '../widgets/account_button.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/class_detail_sheet.dart';
import '../widgets/elbee_sheet.dart';
import 'pet_customization_screen.dart';

/// Pet Home: Elbee in their room with the level, gems, the Quest / Shop /
/// Pack / Guide actions, and today's missions and upcoming classes.
///
/// Read-only over [AppState]: gems are the verified wallet balance, and
/// missions are claimed in the Calendar, where the server checks them.
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key});

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    side: BorderSide(color: AppColors.cardBorder),
  );

  bool _refreshFailed = false;

  Future<void> _refresh() async {
    setState(() => _refreshFailed = false);
    try {
      await context.read<AppState>().refreshClasses();
    } catch (_) {
      // refreshClasses records API errors itself; a dropped connection throws.
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

  Future<void> _openPack() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final outfit = await showModalBottomSheet<PetOutfit>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => _PackSheet(
        owned: [
          for (final outfit in petOutfits)
            if (state.ownedOutfits.contains(outfit.id)) outfit,
        ],
        equippedId: state.equippedOutfit,
        onOpenShop: () {
          Navigator.pop(sheetContext);
          context.push('/pet/shop');
        },
      ),
    );
    if (outfit == null) return;
    try {
      await state.equipOutfit(outfit.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not wear ${outfit.label}: $error')),
      );
    }
  }

  void _showMission(DailyClassTask task) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => _MissionSheet(
        task: task,
        onOpenCalendar: () {
          Navigator.pop(sheetContext);
          context.go('/checklist');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final classes = state.classes;
    final loading = state.classesBusy && classes.isEmpty;
    final error =
        state.classesError ??
        (_refreshFailed
            ? 'Could not reach NaviPet. Check your connection and try again.'
            : null);
    final missions = state.dailyTasks();
    final now = DateTime.now();
    final completions = classes.fold<int>(
      0,
      (sum, course) => sum + state.completionCountFor(course.id),
    );

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _room(
                state,
                level: PetLevel(completions),
                loading: loading,
                message: petMessage(
                  loading: loading,
                  failed: error != null,
                  missions: missions,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) _errorCard(error),
                    if (loading)
                      _loadingCard()
                    else if (classes.isEmpty) ...[
                      // After a failed load "no classes" would be a guess.
                      if (error == null) _emptyCard(),
                    ] else ...[
                      _sectionTitle("Today's missions"),
                      for (final task in missions) _missionTile(task),
                      const SizedBox(height: AppSpacing.lg),
                      _sectionTitle('Upcoming classes'),
                      for (final next in upcomingClasses(classes, now))
                        _classTile(next, now),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NaviBottomNav(active: NaviTab.pets),
    );
  }

  Widget _room(
    AppState state, {
    required PetLevel level,
    required bool loading,
    required String message,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    final equipped = petOutfits
        .where((outfit) => outfit.id == state.equippedOutfit)
        .firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _RoomPainter(windowTop: topInset + 76)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topInset + AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _levelBadge(level)),
                  const SizedBox(width: AppSpacing.sm),
                  _gems(loading ? null : state.points),
                  const AccountButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _pet(equipped),
                        const SizedBox(height: AppSpacing.sm),
                        _bubble(message),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpacing.sm,
                      children: [
                        _action(
                          Icons.flag_outlined,
                          'Quest',
                          () => context.go('/checklist'),
                        ),
                        _action(
                          Icons.storefront_outlined,
                          'Shop',
                          () => context.push('/pet/shop'),
                        ),
                        _action(Icons.backpack_outlined, 'Pack', _openPack),
                        _action(Icons.explore_outlined, 'Guide', _openGuide),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelBadge(PetLevel level) => Semantics(
    container: true,
    label:
        'Level ${level.level}, ${level.current} of ${PetLevel.perLevel} '
        'verified missions to the next level',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${level.level}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.petInk,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Level ${level.level}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.petInk,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: level.progress,
                      minHeight: 8,
                      color: AppColors.yellow,
                      backgroundColor: AppColors.cardBorder,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
        ),
      ),
    ),
  );

  /// The wallet balance; [points] is null until the first load finishes, so
  /// the chip never shows a zero that is only a placeholder.
  Widget _gems(int? points) => Semantics(
    container: true,
    label: points == null ? 'Gems loading' : '$points gems',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond_outlined, size: 16, color: AppColors.blue),
            const SizedBox(width: AppSpacing.xs),
            Text(
              points?.toString() ?? '...',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.petInk,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _pet(PetOutfit? equipped) {
    final image = petImageFor(equipped?.id);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // The cushion Elbee sits on.
        Container(
          width: 190,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFF6B8C6),
            borderRadius: BorderRadius.all(Radius.elliptical(95, 20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Image.asset(
            image,
            height: 190,
            semanticLabel: equipped == null
                ? 'Elbee the shark'
                : 'Elbee the shark, wearing ${equipped.label}',
          ),
        ),
        // Outfits without their own artwork still show as worn.
        if (equipped != null && image == petImageFor(null))
          Positioned(
            right: 0,
            bottom: 14,
            child: CircleAvatar(
              backgroundColor: AppColors.yellow,
              child: Icon(equipped.icon, color: AppColors.petInk),
            ),
          ),
      ],
    );
  }

  Widget _bubble(String message) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppShadows.soft,
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.petInk,
      ),
    ),
  );

  Widget _action(IconData icon, String label, VoidCallback onTap) => Semantics(
    key: ValueKey('pet-action-$label'),
    container: true,
    button: true,
    child: Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.petInk),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.petInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.petInk,
        ),
      ),
    ),
  );

  Widget _missionTile(DailyClassTask task) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    elevation: 0,
    color: AppColors.surface,
    shape: _cardShape,
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: () => _showMission(task),
      leading: Icon(
        task.done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.done ? AppColors.green : AppColors.muted,
      ),
      title: Text(
        task.label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.petInk,
        ),
      ),
      subtitle: Text(
        '${task.done ? 'Completed · ' : ''}'
        '${task.course.courseCode} · ${task.course.timeRangeLabel}',
        style: const TextStyle(color: AppColors.labelInk),
      ),
      trailing: Text(
        '+${task.reward}',
        semanticsLabel: '${task.reward} gems',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.gemInk,
        ),
      ),
    ),
  );

  Widget _classTile(UpcomingClass next, DateTime now) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    elevation: 0,
    color: AppColors.surface,
    shape: _cardShape,
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: () => showClassDetailSheet(context, next.course),
      leading: Icon(
        next.course.isOnline
            ? Icons.videocam_outlined
            : Icons.location_on_outlined,
        color: AppColors.petInk,
      ),
      title: Text(
        '${next.course.courseCode} · ${next.course.courseName}',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.petInk,
        ),
      ),
      subtitle: Text(
        '${upcomingDayLabel(next.start, now)} · '
        '${next.course.timeRangeLabel}\n${next.course.locationLabel}',
        style: const TextStyle(color: AppColors.labelInk),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.petInk),
    ),
  );

  Widget _loadingCard() => const Padding(
    padding: EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpacing.md),
        Text('Loading your day...', style: TextStyle(color: AppColors.petInk)),
      ],
    ),
  );

  Widget _emptyCard() => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    shape: _cardShape,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No classes yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.petInk,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Add your classes in the Calendar to get daily missions.',
            style: TextStyle(color: AppColors.labelInk),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => context.go('/checklist'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.petInk,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Open Calendar'),
          ),
        ],
      ),
    ),
  );

  Widget _errorCard(String message) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
    elevation: 0,
    color: AppColors.surface,
    shape: _cardShape,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  "Couldn't load your classes. $message",
                  style: const TextStyle(color: AppColors.petInk),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

/// The outfits already owned. Choosing one pops it for Pet Home to equip
/// through the existing `equip_outfit` RPC; nothing is bought here.
class _PackSheet extends StatelessWidget {
  const _PackSheet({
    required this.owned,
    required this.equippedId,
    required this.onOpenShop,
  });

  final List<PetOutfit> owned;
  final String? equippedId;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pack',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.petInk,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (owned.isEmpty) ...[
            const Text(
              'Your pack is empty. Outfits you buy in the Shop show up here.',
              style: TextStyle(color: AppColors.labelInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onOpenShop,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.petInk,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Open Shop'),
            ),
          ] else
            for (final outfit in owned)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(outfit.icon, color: AppColors.petInk),
                title: Text(
                  outfit.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.petInk,
                  ),
                ),
                trailing: outfit.id == equippedId
                    ? const Text(
                        'Wearing',
                        style: TextStyle(color: AppColors.labelInk),
                      )
                    : TextButton(
                        onPressed: () => Navigator.pop(context, outfit),
                        child: Text(
                          'Wear',
                          semanticsLabel: 'Wear ${outfit.label}',
                        ),
                      ),
              ),
        ],
      ),
    ),
  );
}

/// What a mission asks for and how it is verified. Claiming stays in the
/// Calendar, so this sheet can never grant a reward.
class _MissionSheet extends StatelessWidget {
  const _MissionSheet({required this.task, required this.onOpenCalendar});

  final DailyClassTask task;
  final VoidCallback onOpenCalendar;

  String get _howTo => switch (task.kind) {
    'attend' =>
      'Check in from the Calendar while you are near the class building '
          'during class time.',
    'attend_online' =>
      'Run the online session from the Calendar for the scheduled class time.',
    _ => 'Mark this done from the Calendar today.',
  };

  @override
  Widget build(BuildContext context) {
    final course = task.course;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.petInk,
              ),
            ),
            Text(
              '${course.courseCode} · ${course.courseName}',
              style: const TextStyle(fontSize: 15, color: AppColors.labelInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            _row(Icons.schedule, course.timeRangeLabel),
            _row(
              course.isOnline
                  ? Icons.videocam_outlined
                  : Icons.location_on_outlined,
              course.locationLabel,
            ),
            _row(
              Icons.diamond_outlined,
              '${task.reward} gems, added once NaviPet verifies the mission',
            ),
            _row(
              task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              task.done ? 'Completed today' : 'Not completed yet',
            ),
            Text(_howTo, style: const TextStyle(color: AppColors.petInk)),
            if (task.kind == 'attend') ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'A campus check-in confirms you were near the building. It is '
                'not proof of class attendance.',
                style: TextStyle(color: AppColors.labelInk),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onOpenCalendar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.petInk,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Open Calendar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.petInk),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: AppColors.petInk),
          ),
        ),
      ],
    ),
  );
}

/// Elbee's room: a warm wall with a window, over a lilac checkered floor.
class _RoomPainter extends CustomPainter {
  const _RoomPainter({required this.windowTop});

  /// Keeps the window below the status bar and the header row.
  final double windowTop;

  @override
  void paint(Canvas canvas, Size size) {
    final floorTop = size.height * 0.62;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.accentSoft);

    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(AppSpacing.xl, windowTop, 96, 84),
      const Radius.circular(AppRadius.sm),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFFBFE3F7));
    final frame = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(window, frame);
    canvas.drawLine(
      Offset(window.center.dx, window.top),
      Offset(window.center.dx, window.bottom),
      frame,
    );
    canvas.drawLine(
      Offset(window.left, window.center.dy),
      Offset(window.right, window.center.dy),
      frame,
    );

    const tile = 32.0;
    final light = Paint()..color = const Color(0xFFEDE4FA);
    final dark = Paint()..color = const Color(0xFFDFD2F4);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, floorTop, size.width, size.height));
    for (var row = 0; floorTop + row * tile < size.height; row++) {
      for (var column = 0; column * tile < size.width; column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * tile, floorTop + row * tile, tile, tile),
          (row + column).isEven ? light : dark,
        );
      }
    }
    canvas.restore();
    // Baseboard.
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop - 6, size.width, 6),
      Paint()..color = AppColors.surface,
    );
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) =>
      oldDelegate.windowTop != windowTop;
}
