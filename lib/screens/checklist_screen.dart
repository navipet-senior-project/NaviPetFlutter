import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/class_detail_sheet.dart';
import '../widgets/class_editor_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/schedule_calendar.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // Set on the label, not through ButtonStyle.textStyle, which would replace
  // the theme's label style and drop the brand font.
  static const _buttonLabel = TextStyle(fontWeight: FontWeight.w700);

  DateTime _selectedDate = DateTime.now();
  CalendarView _view = CalendarView.week;
  int _scrollToNowRequest = 0;
  Timer? _onlineTimer;
  final _pageController = ScrollController();
  final _dailyTasksKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Only the running online-session counters change every second.
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<AppState>().hasRunningOnlineSession) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _edit(BuildContext context, [CourseClass? course]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppState>(),
        child: ClassEditorSheet(course: course),
      ),
    );
  }

  void _showClass(BuildContext context, CourseClass course) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => ClassDetailSheet(
        course: course,
        completions: context.read<AppState>().completionCountFor(course.id),
        onEdit: () {
          Navigator.pop(sheetContext);
          _edit(context, course);
        },
      ),
    );
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _view = CalendarView.day;
      _scrollToNowRequest++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _dailyTasksKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.08,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.dailyTasks(_selectedDate);
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/map'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => context.push('/account'),
            icon: ProfileAvatar(
              name: state.activeUser?.name ?? '?',
              color: state.activeUser?.avatarColor ?? AppColors.amber,
              imageUrl: state.activeUser?.avatarUrl,
              size: 32,
              onImageError: state.reportAvatarLoadFailed,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshClasses,
        child: ListView(
          controller: _pageController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _intro(context),
            const SizedBox(height: AppSpacing.lg),
            _calendarToolbar(),
            const SizedBox(height: AppSpacing.md),
            ScheduleCalendar(
              classes: state.classes,
              selectedDate: _selectedDate,
              view: _view,
              scrollToNowRequest: _scrollToNowRequest,
              onSelectDate: (date) => setState(() => _selectedDate = date),
              onTapClass: (course) => _showClass(context, course),
            ),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle(
              'Class achievements',
              '${state.classes.length} ${state.classes.length == 1 ? 'class' : 'classes'}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.classesBusy && state.classes.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (state.classes.isEmpty)
              _emptyClasses(context)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 128,
                ),
                itemCount: state.classes.length,
                itemBuilder: (_, index) => _achievementCard(
                  context,
                  state.classes[index],
                  state.completionCountFor(state.classes[index].id),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              key: _dailyTasksKey,
              child: _sectionTitle(
                'Daily tasks',
                '${tasks.where((task) => task.done).length}/${tasks.length} done',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (tasks.isEmpty)
              const Text('Add a class to create personalized daily tasks.')
            else
              _taskList(context, state, tasks),
          ],
        ),
      ),
      // The Add class action sits in its own bar above the tabs so it never
      // covers the calendar.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _addClassBar(context, state),
          const NaviBottomNav(active: NaviTab.menu),
        ],
      ),
    );
  }

  Widget _calendarToolbar() => Row(
    children: [
      Expanded(
        child: SegmentedButton<CalendarView>(
          segments: const [
            ButtonSegment(
              value: CalendarView.week,
              label: Text('Week', style: _buttonLabel),
            ),
            ButtonSegment(
              value: CalendarView.day,
              label: Text('Day', style: _buttonLabel),
            ),
            ButtonSegment(
              value: CalendarView.agenda,
              label: Text('Agenda', style: _buttonLabel),
            ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (views) => setState(() => _view = views.first),
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.petInk,
            selectedBackgroundColor: AppColors.petInk,
            selectedForegroundColor: Colors.white,
            side: const BorderSide(color: AppColors.cardBorder),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: _goToToday,
        icon: const Icon(Icons.today_outlined, size: 18),
        label: const Text('Today', style: _buttonLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.petInk,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.petInk),
          visualDensity: VisualDensity.compact,
        ),
      ),
    ],
  );

  Widget _addClassBar(BuildContext context, AppState state) {
    final today = state.classes
        .where((course) => course.occursOn(DateTime.now().weekday))
        .length;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              today == 0
                  ? 'No classes today'
                  : '$today ${today == 1 ? 'class' : 'classes'} today',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.labelInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _edit(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.petInk,
              minimumSize: const Size(0, 40),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add class', style: _buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _intro(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: AppColors.petInk,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.yellow,
          backgroundImage: AssetImage('assets/images/shark_side.png'),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your class journey',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Complete class-aware tasks to grow your achievements.',
                style: TextStyle(color: Color(0xFFD9E6F4), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String detail) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.petInk,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(
        detail,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  );

  Widget _emptyClasses(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.school_outlined, size: 38, color: AppColors.petInk),
            SizedBox(height: 8),
            Text(
              'Add your first class',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Your tasks, achievements, and nearby places will adapt automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _achievementCard(BuildContext context, CourseClass course, int count) {
    final progress = count.clamp(0, ClassDetailSheet.goal);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showClass(context, course),
          splashColor: AppColors.yellow.withValues(alpha: .25),
          highlightColor: AppColors.accentSoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      course.isOnline
                          ? Icons.videocam_outlined
                          : Icons.workspace_premium_outlined,
                      size: 20,
                      color: AppColors.petInk,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        course.courseCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.petInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  course.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.labelInk,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress / ClassDetailSheet.goal,
                          minHeight: 8,
                          color: AppColors.yellow,
                          backgroundColor: AppColors.cardBorder,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$progress/${ClassDetailSheet.goal}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.petInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${count == 1 ? 'task' : 'tasks'} completed',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskList(
    BuildContext context,
    AppState state,
    List<DailyClassTask> tasks,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppShadows.soft,
    ),
    child: Column(
      children: [
        for (var index = 0; index < tasks.length; index++) ...[
          ListTile(
            onTap: () => _handleTask(context, state, tasks[index]),
            leading: Checkbox(
              value: tasks[index].done,
              activeColor: AppColors.petInk,
              onChanged: (_) => _handleTask(context, state, tasks[index]),
            ),
            title: Text(
              tasks[index].label,
              style: TextStyle(
                decoration: tasks[index].done
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: tasks[index].kind == 'attend_online'
                ? Text(
                    'Online session: ${_durationLabel(state.onlineSessionDuration(tasks[index].course.id))} / ${_durationLabel(state.onlineSessionRequirement(tasks[index].course))} required',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    '${tasks[index].course.startLabel} · ${tasks[index].course.courseName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: tasks[index].done
                ? const Icon(Icons.check_circle, color: AppColors.green)
                : tasks[index].kind == 'attend_online'
                ? TextButton(
                    onPressed: () {
                      final id = tasks[index].course.id;
                      if (state.onlineSessionRunning(id)) {
                        _handleTask(context, state, tasks[index]);
                      } else {
                        state.startOnlineSession(id);
                      }
                    },
                    child: Text(
                      state.onlineSessionRunning(tasks[index].course.id)
                          ? 'Claim'
                          : 'Start',
                    ),
                  )
                : Text(
                    '+${tasks[index].reward} 💎',
                    style: const TextStyle(
                      color: AppColors.gemInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          if (index < tasks.length - 1) const Divider(height: 1, indent: 64),
        ],
      ],
    ),
  );

  Future<void> _handleTask(
    BuildContext context,
    AppState state,
    DailyClassTask task,
  ) async {
    try {
      final result = await state.verifyAndToggleTask(task, _selectedDate);
      final message = switch (result) {
        TaskClaimResult.claimed => null,
        TaskClaimResult.notToday =>
          'Tasks can only be completed on the day they are scheduled.',
        TaskClaimResult.sessionTooShort =>
          'Keep the online session running for the scheduled class duration before claiming points.',
        TaskClaimResult.locationUnavailable =>
          'Turn on location access to check in to this class.',
        TaskClaimResult.tooFar =>
          'You need to be near the class building to complete this task.',
      };
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update task: $error')),
        );
      }
    }
  }

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
