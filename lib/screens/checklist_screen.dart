import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/course_class.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/class_editor_sheet.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  DateTime _selectedDate = DateTime.now();
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
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
        title: const Text('Achievements'),
        actions: [
          IconButton(
            tooltip: 'Add class',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_circle, color: AppColors.petInk),
          ),
          IconButton(
            onPressed: () => context.push('/account'),
            icon: const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/shark_face.png'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshClasses,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _intro(context),
            const SizedBox(height: 24),
            _scheduleCalendar(state.classes),
            const SizedBox(height: 24),
            _sectionTitle(
              'Daily tasks',
              '${tasks.where((task) => task.done).length}/${tasks.length} done',
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              const Text('Add a class to create personalized daily tasks.')
            else
              _taskList(context, state, tasks),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.petInk,
        icon: const Icon(Icons.add),
        label: const Text('Add class'),
      ),
      bottomNavigationBar: const NaviBottomNav(active: NaviTab.menu),
    );
  }

  Widget _scheduleCalendar(List<CourseClass> classes) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday - 1));
    const dayWidth = 96.0;
    const timeWidth = 58.0;
    const rowHeight = 68.0;
    const startHour = 8;
    const endHour = 19;
    final gridHeight = (endHour - startHour) * rowHeight;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: timeWidth + dayWidth * 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.petInk),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: Row(
                  children: [
                    const SizedBox(width: timeWidth),
                    ...List.generate(7, (index) {
                      final date = start.add(Duration(days: index));
                      return SizedBox(
                        width: dayWidth,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: Column(
                            children: [
                              Text(dayNames[index], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                              Text('${date.month}/${date.day}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.petInk)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(
                height: gridHeight,
                child: Stack(
                  children: [
                    for (var row = 0; row <= endHour - startHour; row++)
                      Positioned(
                        top: row * rowHeight,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: timeWidth,
                              child: Text(
                                _hourLabel(startHour + row),
                                style: const TextStyle(fontSize: 10, color: AppColors.muted),
                              ),
                            ),
                            Container(width: dayWidth * 7, height: 1, color: AppColors.cardBorder),
                          ],
                        ),
                      ),
                    for (var day = 0; day < 7; day++)
                      Positioned(
                        left: timeWidth + day * dayWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: AppColors.cardBorder),
                      ),
                    for (final course in classes)
                      for (final weekday in course.weekdays)
                        if (weekday >= 1 && weekday <= 7)
                          _classBlock(course, weekday - 1, dayWidth, timeWidth, rowHeight, startHour),
                  ],
                ),
              ),
              if (classes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Add a class to populate your schedule.', style: TextStyle(color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _hourLabel(int hour) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:00 $suffix';
  }

  Widget _classBlock(CourseClass course, int day, double dayWidth, double timeWidth, double rowHeight, int startHour) {
    final start = _minutes(course.startTime);
    final end = _minutes(course.endTime);
    final top = ((start - startHour * 60) / 60 * rowHeight)
        .clamp(0.0, 740.0)
        .toDouble();
    final height = (((end - start) / 60 * rowHeight).clamp(42.0, 740.0)).toDouble();
    return Positioned(
      left: timeWidth + day * dayWidth + 4,
      top: top,
      width: dayWidth - 8,
      height: height,
      child: GestureDetector(
        onTap: () => _edit(context, course),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: course.isOnline ? const Color(0xFFD9E8F7) : const Color(0xFFC5DDA2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.petInk.withValues(alpha: .18)),
          ),
          child: Text(
            '${course.courseCode}\n${course.courseName}\n${course.startTime}-${course.endTime}\n${course.locationLabel}',
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, height: 1.15, color: AppColors.petInk, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return (int.tryParse(parts.first) ?? 8) * 60 + (int.tryParse(parts.elementAt(1)) ?? 0);
  }

  Widget _intro(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.petInk,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: AppColors.yellow,
          backgroundImage: AssetImage('assets/images/shark_side.png'),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your class journey',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 4),
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
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.petInk,
        ),
      ),
      Text(
        detail,
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ],
  );

  Widget _emptyClasses(BuildContext context) => InkWell(
    onTap: () => _edit(context),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
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
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _achievementCard(BuildContext context, CourseClass course, int count) {
    final progress = count.clamp(0, 5);
    return InkWell(
      onTap: () => _edit(context, course),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: AppColors.yellow, width: 4),
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              course.isOnline
                  ? Icons.video_camera_front_outlined
                  : Icons.workspace_premium_outlined,
              size: 30,
              color: AppColors.petInk,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  course.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  course.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.faint, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    5,
                    (index) => Expanded(
                      child: Container(
                        height: 7,
                        margin: EdgeInsets.only(right: index == 4 ? 0 : 3),
                        decoration: BoxDecoration(
                          color: index < progress
                              ? AppColors.yellow
                              : AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count tasks completed · Tap to edit',
                  style: const TextStyle(fontSize: 10, color: AppColors.faint),
                ),
              ],
            ),
          ],
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
              '${tasks[index].course.startTime} · ${tasks[index].course.courseName}',
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
      final completed = await state.verifyAndToggleTask(task, _selectedDate);
      if (!completed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              task.kind == 'attend_online'
                  ? 'Keep the online session running for the scheduled class duration before claiming points.'
                  : 'You need to be near the class building to complete this task.',
            ),
          ),
        );
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
