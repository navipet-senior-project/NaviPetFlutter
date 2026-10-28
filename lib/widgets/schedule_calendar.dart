import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/course_class.dart';
import '../theme/app_theme.dart';

/// How [ScheduleCalendar] lays out the current week.
enum CalendarView { week, day, agenda }

/// The user's weekly classes as a time grid of the current week (Mon–Sun), a
/// time grid of the selected day, or an agenda of the next seven days.
///
/// The grid fits all seven days to the available width, grows its hours to
/// fit the earliest and latest class, and scrolls itself to the current time.
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.classes,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onTapClass,
    this.view = CalendarView.week,
    this.scrollToNowRequest = 0,
    this.today,
    this.parentScrollController,
  });

  final List<CourseClass> classes;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<CourseClass> onTapClass;
  final CalendarView view;

  /// Bump to scroll the grid back to the current time (the Today button).
  final int scrollToNowRequest;

  /// Overrides the current date and time; for tests.
  final DateTime? today;

  /// Receives the unused scroll delta when the time grid reaches either edge.
  final ScrollController? parentScrollController;

  static const gridKey = ValueKey('schedule-grid');
  static const nowLineKey = ValueKey('schedule-now');

  static const _defaultStartHour = 0;
  static const _defaultEndHour = 24;

  /// The hour span the grid shows: the complete 24-hour day.
  static ({int startHour, int endHour}) hourRange(
    Iterable<CourseClass> classes,
  ) {
    // Keep a consistent full-day grid even when the schedule is empty or
    // contains only daytime classes.
    return (startHour: _defaultStartHour, endHour: _defaultEndHour);
  }

  static int _minutes(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? _defaultStartHour;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  static const _timeWidth = 44.0;
  static const _rowHeight = 56.0;
  static const _viewportRows = 6.5;
  static const _minBlockHeight = 36.0;
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _onlineFill = Color(0xFFE3EDF8);

  final _scroll = ScrollController();

  DateTime get _now => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void didUpdateWidget(ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollToNowRequest != widget.scrollToNowRequest ||
        oldWidget.view != widget.view) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToNow(animate: true),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the grid so the current time sits an hour below the top.
  void _scrollToNow({bool animate = false}) {
    if (!mounted || !_scroll.hasClients) return;
    final (:startHour, endHour: _) = ScheduleCalendar.hourRange(widget.classes);
    final now = _now;
    final minutes = now.hour * 60 + now.minute - (startHour + 1) * 60;
    final target = (minutes / 60 * _rowHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<CourseClass> _classesOn(int weekday) =>
      widget.classes.where((course) => course.occursOn(weekday)).toList()..sort(
        (a, b) => ScheduleCalendar._minutes(
          a.startTime,
        ).compareTo(ScheduleCalendar._minutes(b.startTime)),
      );

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final days = [
      for (var index = 0; index < 7; index++)
        DateTime(weekStart.year, weekStart.month, weekStart.day + index),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: widget.view == CalendarView.agenda
          ? _agenda([
              for (var index = 0; index < 7; index++)
                DateTime(now.year, now.month, now.day + index),
            ], now)
          : LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = (constraints.maxWidth - _timeWidth) / 7;
                final selected = days.firstWhere(
                  (day) => _sameDay(day, widget.selectedDate),
                  orElse: () => widget.selectedDate,
                );
                final columns = widget.view == CalendarView.week
                    ? days
                    : [selected];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: _timeWidth),
                        for (final day in days) _dayChip(day, dayWidth, now),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _grid(
                      columns,
                      (constraints.maxWidth - _timeWidth) / columns.length,
                      now,
                    ),
                    if (widget.classes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          'Add a class to populate your schedule.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _dayChip(DateTime date, double width, DateTime now) {
    final selected = _sameDay(date, widget.selectedDate);
    final isToday = _sameDay(date, now);
    final foreground = selected ? Colors.white : AppColors.petInk;
    return SizedBox(
      width: width,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          label: isToday ? 'Today' : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: selected
                  ? AppColors.petInk
                  : isToday
                  ? AppColors.yellow
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => widget.onSelectDate(date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(
                          _dayNames[date.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : isToday
                                ? AppColors.yellowInk
                                : AppColors.muted,
                          ),
                        ),
                        Text(
                          '${date.month}/${date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                        // A shape, not only a colour, marks today.
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? foreground : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(List<DateTime> columns, double columnWidth, DateTime now) {
    final (:startHour, :endHour) = ScheduleCalendar.hourRange(widget.classes);
    final gridHeight = (endHour - startHour) * _rowHeight;
    final nowMinutes = now.hour * 60 + now.minute;
    final todayColumn = columns.indexWhere((day) => _sameDay(day, now));
    final showNow =
        todayColumn >= 0 &&
        nowMinutes >= startHour * 60 &&
        nowMinutes <= endHour * 60;
    return SizedBox(
      height: math.min(gridHeight, _rowHeight * _viewportRows),
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          final parent = widget.parentScrollController;
          if (notification.depth != 0 || parent == null || !parent.hasClients) {
            return false;
          }
          final position = parent.position;
          final target = (position.pixels + notification.overscroll).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if (target == position.pixels) return false;
          parent.jumpTo(target);
          return true;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            key: ScheduleCalendar.gridKey,
            height: gridHeight,
            child: Stack(
              children: [
                for (var row = 0; row <= endHour - startHour; row++)
                  Positioned(
                    top: math.min(row * _rowHeight, gridHeight - 1),
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _timeWidth,
                          child: row == endHour - startHour
                              ? null
                              : Text(
                                  _hourLabel(startHour + row),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: AppColors.divider),
                        ),
                      ],
                    ),
                  ),
                for (var index = 0; index < columns.length; index++)
                  Positioned(
                    left: _timeWidth + index * columnWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: AppColors.divider),
                  ),
                for (var index = 0; index < columns.length; index++)
                  for (final course in _classesOn(columns[index].weekday))
                    _block(
                      course,
                      columns[index].weekday,
                      left: _timeWidth + index * columnWidth,
                      width: columnWidth,
                      startHour: startHour,
                      gridHeight: gridHeight,
                      compact: columns.length > 1,
                    ),
                if (showNow)
                  Positioned(
                    key: ScheduleCalendar.nowLineKey,
                    left: _timeWidth + todayColumn * columnWidth - 4,
                    width: columnWidth + 4,
                    top: (nowMinutes - startHour * 60) / 60 * _rowHeight - 4,
                    height: 8,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accentDark,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hourLabel(int hour) {
    final suffix = hour >= 12 && hour < 24 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $suffix';
  }

  String _semanticLabel(CourseClass course) =>
      '${course.courseCode}, ${course.courseName}, ${course.timeRangeLabel}'
      '${course.isOnline ? ', online' : ''}';

  Widget _block(
    CourseClass course,
    int weekday, {
    required double left,
    required double width,
    required int startHour,
    required double gridHeight,
    required bool compact,
  }) {
    final start = ScheduleCalendar._minutes(course.startTime);
    final end = ScheduleCalendar._minutes(course.endTime);
    final top = ((start - startHour * 60) / 60 * _rowHeight).clamp(
      0.0,
      gridHeight - _minBlockHeight,
    );
    final height = ((end - start) / 60 * _rowHeight).clamp(
      _minBlockHeight,
      gridHeight - top,
    );
    final accent = course.isOnline ? AppColors.navy : AppColors.yellow;
    return Positioned(
      key: ValueKey('class-${course.id}-$weekday'),
      left: left + 2,
      top: top,
      width: width - 4,
      height: height,
      child: Semantics(
        button: true,
        label: _semanticLabel(course),
        excludeSemantics: true,
        child: Material(
          color: course.isOnline ? _onlineFill : AppColors.accentSoft,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onTapClass(course),
            splashColor: AppColors.petInk.withValues(alpha: .14),
            highlightColor: AppColors.petInk.withValues(alpha: .08),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
              child: compact
                  ? _compactLabel(course)
                  : Text.rich(
                      _fullLabel(course),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InlineSpan _onlineIcon(double size) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(Icons.videocam_outlined, size: size, color: AppColors.navy),
    ),
  );

  /// Course code split at its space (`CECS` / `491A`) and the start time,
  /// each line shrunk to fit so a narrow week column never breaks a word.
  /// Clipped rather than overflowing when the class is short.
  Widget _compactLabel(CourseClass course) {
    final parts = course.courseCode.trim().split(RegExp(r'\s+'));
    final lines = parts.length > 1
        ? [parts.first, parts.skip(1).join(' ')]
        : [course.courseCode];
    Widget fit(Widget child) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: child,
    );
    const code = TextStyle(
      fontSize: 11,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: AppColors.petInk,
    );
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) fit(Text(line, style: code)),
            fit(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (course.isOnline)
                    const Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.videocam_outlined,
                        size: 12,
                        color: AppColors.navy,
                      ),
                    ),
                  Text(
                    formatClockTime(course.startTime, period: false),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _fullLabel(CourseClass course) => TextSpan(
    style: const TextStyle(color: AppColors.petInk, height: 1.25),
    children: [
      TextSpan(
        text: '${course.courseCode}\n',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      TextSpan(
        text: '${course.courseName}\n',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      if (course.isOnline) _onlineIcon(14),
      TextSpan(
        text: course.timeRangeLabel,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _agenda(List<DateTime> days, DateTime now) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final day in days) ...[
        _agendaHeader(day, isToday: _sameDay(day, now)),
        if (_classesOn(day.weekday) case final classes when classes.isNotEmpty)
          for (final course in classes) _agendaTile(course, day.weekday)
        else
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(
              'No classes',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        if (day != days.last) const Divider(height: AppSpacing.lg),
      ],
    ],
  );

  Widget _agendaHeader(DateTime day, {required bool isToday}) {
    final label =
        '${_dayNames[day.weekday - 1]}, ${_monthNames[day.month - 1]} ${day.day}';
    final selected = _sameDay(day, widget.selectedDate);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => widget.onSelectDate(day),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.sm),
          child: Row(
            children: [
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    size: 14,
                    color: AppColors.yellowInk,
                  ),
                ),
              Text(
                isToday ? 'Today · $label' : label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday || selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: AppColors.petInk,
                  decoration: selected && !isToday
                      ? TextDecoration.underline
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agendaTile(CourseClass course, int weekday) => Padding(
    key: ValueKey('agenda-${course.id}-$weekday'),
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Semantics(
      button: true,
      label: _semanticLabel(course),
      excludeSemantics: true,
      child: Material(
        color: course.isOnline ? _onlineFill : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onTapClass(course),
          splashColor: AppColors.petInk.withValues(alpha: .14),
          highlightColor: AppColors.petInk.withValues(alpha: .08),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: course.isOnline ? AppColors.navy : AppColors.yellow,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseCode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.petInk,
                        ),
                      ),
                      Text(
                        course.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.labelInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            course.isOnline
                                ? Icons.videocam_outlined
                                : Icons.schedule,
                            size: 14,
                            color: AppColors.petInk,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.timeRangeLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.petInk,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
