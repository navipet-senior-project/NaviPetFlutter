import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/course_class.dart';
import 'package:navipet/data/pet_home.dart';

CourseClass _class(
  String id,
  List<int> weekdays, {
  String start = '10:00',
  String end = '11:15',
}) => CourseClass(
  id: id,
  courseCode: 'CECS $id',
  courseName: 'Course $id',
  building: 'VEC',
  room: '308',
  weekdays: weekdays,
  startTime: start,
  endTime: end,
  latitude: 33.78,
  longitude: -118.11,
);

DailyClassTask _mission(CourseClass course, {required bool done}) =>
    DailyClassTask(
      course: course,
      kind: 'attend',
      label: 'Go to class',
      reward: 10,
      done: done,
    );

void main() {
  // Wednesday 2026-11-11, 12:00.
  final now = DateTime(2026, 11, 11, 12);

  test('level rises every five verified completions', () {
    expect(const PetLevel(0).level, 1);
    expect(const PetLevel(0).progress, 0);
    expect(const PetLevel(4).level, 1);
    expect(const PetLevel(5).level, 2);
    expect(const PetLevel(7).level, 2);
    expect(const PetLevel(7).current, 2);
    expect(const PetLevel(7).progress, closeTo(0.4, 1e-9));
  });

  test('only outfits with artwork change the shark image', () {
    expect(petImageFor(null), 'assets/images/elbee.png');
    expect(petImageFor('grad_cap'), 'assets/images/elbee_graduate.png');
    expect(petImageFor('csulb_tee'), 'assets/images/elbee_sport.png');
    expect(petImageFor('shades'), petImageFor(null));
  });

  test('the message follows the state of the day', () {
    final course = _class('1', [3]);
    String message({
      bool loading = false,
      bool failed = false,
      List<DailyClassTask> missions = const [],
    }) => petMessage(loading: loading, failed: failed, missions: missions);

    expect(message(failed: true, loading: true), contains("couldn't load"));
    expect(message(loading: true), contains('Checking'));
    expect(message(), contains('Add a class'));
    expect(
      message(missions: [_mission(course, done: false)]),
      startsWith('1 mission left'),
    );
    expect(
      message(
        missions: [
          _mission(course, done: false),
          _mission(course, done: false),
          _mission(course, done: true),
        ],
      ),
      startsWith('2 missions left'),
    );
    expect(
      message(missions: [_mission(course, done: true)]),
      contains('All missions done'),
    );
  });

  test('upcoming classes come soonest first', () {
    final upcoming = upcomingClasses([
      _class('friday', [5]),
      _class('tonight', [3], start: '18:00', end: '19:15'),
      _class('tomorrow', [4]),
    ], now);

    expect(upcoming.map((next) => next.course.id), [
      'tonight',
      'tomorrow',
      'friday',
    ]);
    expect(upcoming.first.start, DateTime(2026, 11, 11, 18));
    expect(upcomingDayLabel(upcoming[0].start, now), 'Today');
    expect(upcomingDayLabel(upcoming[1].start, now), 'Tomorrow');
    expect(upcomingDayLabel(upcoming[2].start, now), 'Fri');
  });

  test('a class in session is upcoming; one that ended waits a week', () {
    final upcoming = upcomingClasses([
      _class('ended', [3]),
      _class('running', [3], start: '11:30', end: '12:45'),
    ], now);

    expect(upcoming.map((next) => next.course.id), ['running', 'ended']);
    expect(upcoming.last.start, DateTime(2026, 11, 18, 10));
    expect(upcomingDayLabel(upcoming.last.start, now), 'Wed');
  });

  test('upcoming classes are capped and skip classes with no weekday', () {
    final classes = [
      for (var i = 0; i < 5; i++) _class('$i', [4]),
      _class('never', []),
    ];

    expect(upcomingClasses(classes, now), hasLength(3));
    expect(upcomingClasses([classes.last], now), isEmpty);
  });
}
