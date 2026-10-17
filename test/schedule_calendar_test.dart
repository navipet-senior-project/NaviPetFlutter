import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/course_class.dart';
import 'package:navipet/widgets/schedule_calendar.dart';

CourseClass _course(String id, String start, String end, List<int> days) =>
    CourseClass(
      id: id,
      courseCode: 'CECS $id',
      courseName: 'Course $id',
      building: 'VEC',
      room: '',
      weekdays: days,
      startTime: start,
      endTime: end,
      latitude: 33.78,
      longitude: -118.11,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<CourseClass> classes,
  DateTime? selected,
  ValueChanged<DateTime>? onSelectDate,
  ValueChanged<CourseClass>? onTapClass,
  CalendarView view = CalendarView.week,
  DateTime? now,
}) {
  final today = now ?? DateTime(2026, 9, 23); // a Wednesday
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ScheduleCalendar(
            classes: classes,
            today: today,
            selectedDate: selected ?? today,
            onSelectDate: onSelectDate ?? (_) {},
            onTapClass: onTapClass ?? (_) {},
            view: view,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('grid hands off scrolling at both edges', (tester) async {
    final parent = ScrollController();
    addTearDown(parent.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: parent,
            children: [
              const SizedBox(height: 100),
              ScheduleCalendar(
                parentScrollController: parent,
                classes: const [],
                today: DateTime(2026, 9, 23),
                selectedDate: DateTime(2026, 9, 23),
                onSelectDate: (_) {},
                onTapClass: (_) {},
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final inner = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(ScheduleCalendar),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    inner.controller!.jumpTo(inner.controller!.position.maxScrollExtent);
    await tester.pump();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -90));
    await tester.pumpAndSettle();
    expect(parent.offset, greaterThan(0));
    parent.jumpTo(100);
    inner.controller!.jumpTo(0);
    await tester.pump();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(parent.offset, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  test('the visible hours always span the full day', () {
    expect(ScheduleCalendar.hourRange(const []), (startHour: 0, endHour: 24));
    expect(
      ScheduleCalendar.hourRange([
        _course('1', '07:00:00', '07:50:00', [1]),
        _course('2', '19:00:00', '21:45:00', [2]),
      ]),
      (startHour: 0, endHour: 24),
    );
  });

  testWidgets('an evening class is drawn fully inside the grid', (
    tester,
  ) async {
    await _pump(
      tester,
      classes: [
        _course('2', '19:00:00', '21:45:00', [3]),
      ],
    );

    final grid = tester.getRect(find.byKey(ScheduleCalendar.gridKey));
    final block = tester.getRect(find.byKey(const ValueKey('class-2-3')));
    expect(block.top, greaterThanOrEqualTo(grid.top));
    expect(block.bottom, lessThanOrEqualTo(grid.bottom));
    expect(block.height, greaterThan(100));
  });

  testWidgets('tapping a day selects it and marks it selected', (tester) async {
    DateTime? picked;
    await _pump(tester, classes: const [], onSelectDate: (d) => picked = d);

    await tester.tap(find.text('9/25'));
    expect(picked, DateTime(2026, 9, 25));

    await _pump(tester, classes: const [], selected: DateTime(2026, 9, 25));
    expect(
      tester.getSemantics(find.text('9/25')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('9/24')),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('the whole week fits a phone-width screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      classes: [
        _course('1', '10:00', '11:15', [1, 7]),
      ],
    );

    for (final label in ['9/21', '9/27']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(rect.right, lessThanOrEqualTo(390), reason: label);
    }
    final sunday = tester.getRect(find.byKey(const ValueKey('class-1-7')));
    expect(sunday.right, lessThanOrEqualTo(390));
  });

  testWidgets('today is announced as today', (tester) async {
    await _pump(tester, classes: const []);
    expect(
      tester.getSemantics(find.text('9/23')),
      isSemantics(label: 'Today\nWed\n9/23', isSelected: true),
    );
  });

  testWidgets('week blocks show the course and start time, not the room', (
    tester,
  ) async {
    await _pump(
      tester,
      classes: [
        _course('1', '14:00', '15:15', [3]),
      ],
    );
    final block = find.byKey(const ValueKey('class-1-3'));
    // The code breaks at its space, never mid-word.
    expect(
      find.descendant(of: block, matching: find.text('CECS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: block, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: block, matching: find.textContaining('2:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: block, matching: find.textContaining('VEC')),
      findsNothing,
    );
  });

  testWidgets('tapping a block opens that class', (tester) async {
    CourseClass? tapped;
    final course = _course('1', '10:00', '11:15', [3]);
    await _pump(tester, classes: [course], onTapClass: (c) => tapped = c);
    // The full-day grid scrolls, so bring the block into view before tapping.
    await tester.ensureVisible(find.byKey(const ValueKey('class-1-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('class-1-3')));
    expect(tapped, course);
  });

  testWidgets('the grid starts scrolled to the current time', (tester) async {
    await _pump(tester, classes: const [], now: DateTime(2026, 9, 23, 16, 30));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ScheduleCalendar),
        matching: find.byType(Scrollable),
      ),
    );
    // An hour of context above now: 3:30 PM is 7.5 hours after 8 AM.
    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      tester.getRect(find.byKey(ScheduleCalendar.nowLineKey)).top,
      greaterThan(tester.getRect(find.byType(Scrollable).first).top),
    );
  });

  testWidgets('day view shows only the selected day with the class name', (
    tester,
  ) async {
    await _pump(
      tester,
      view: CalendarView.day,
      selected: DateTime(2026, 9, 21),
      classes: [
        _course('1', '10:00', '11:15', [1]),
        _course('2', '12:00', '13:15', [2]),
      ],
    );
    expect(find.byKey(const ValueKey('class-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('class-2-2')), findsNothing);
    expect(find.textContaining('Course 1'), findsOneWidget);
    expect(find.textContaining('10:00–11:15 AM'), findsOneWidget);
  });

  testWidgets('agenda lists each day in order with time ranges', (
    tester,
  ) async {
    await _pump(
      tester,
      view: CalendarView.agenda,
      classes: [
        _course('2', '13:00', '14:15', [3]),
        _course('1', '09:00', '09:50', [3]),
      ],
    );
    expect(find.text('Today · Wed, Sep 23'), findsOneWidget);
    final first = tester.getRect(find.byKey(const ValueKey('agenda-1-3')));
    final second = tester.getRect(find.byKey(const ValueKey('agenda-2-3')));
    expect(first.top, lessThan(second.top));
    expect(find.text('9:00–9:50 AM'), findsOneWidget);
    expect(find.text('No classes'), findsNWidgets(6));
  });

  testWidgets('agenda starts today and runs a week ahead', (tester) async {
    await _pump(
      tester,
      view: CalendarView.agenda,
      now: DateTime(2026, 9, 26), // a Saturday
      classes: [
        _course('1', '09:00', '09:50', [1]),
      ],
    );
    final today = tester.getRect(find.text('Today · Sat, Sep 26'));
    final monday = tester.getRect(find.text('Mon, Sep 28'));
    expect(today.top, lessThan(monday.top));
    expect(find.text('Fri, Oct 2'), findsOneWidget);
    expect(find.text('Mon, Sep 21'), findsNothing);
  });
}
