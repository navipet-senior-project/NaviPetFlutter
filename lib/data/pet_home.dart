import 'course_class.dart';

/// Pet Home's level, shown from the server-verified task completions.
///
/// shortcut: derived on the client and granted nothing, so it only counts
/// classes that still exist; replace it when the backend stores a pet level.
class PetLevel {
  const PetLevel(this.completions);

  /// Verified completions needed for each level.
  static const perLevel = 5;

  final int completions;

  int get level => 1 + completions ~/ perLevel;

  /// Completions already counted toward the next level.
  int get current => completions % perLevel;

  double get progress => current / perLevel;
}

/// The Elbee artwork for [outfitId]. Outfits without their own artwork fall
/// back to the plain shark.
String petImageFor(String? outfitId) => switch (outfitId) {
  'grad_cap' => 'assets/images/elbee_graduate.png',
  'csulb_tee' => 'assets/images/elbee_sport.png',
  _ => 'assets/images/elbee.png',
};

/// Elbee's one-line greeting. Local copy only; nothing here is fetched.
String petMessage({
  required bool loading,
  required bool failed,
  required List<DailyClassTask> missions,
}) {
  if (failed) return "I couldn't load your day. Let's try again.";
  if (loading) return 'Checking your schedule...';
  if (missions.isEmpty) return "Add a class and I'll plan our day!";
  final left = missions.where((mission) => !mission.done).length;
  if (left == 0) return 'All missions done today. Fin-tastic!';
  return '$left ${left == 1 ? 'mission' : 'missions'} left today. '
      "Let's go!";
}

/// A class and the start of its next meeting.
class UpcomingClass {
  const UpcomingClass(this.course, this.start);

  final CourseClass course;
  final DateTime start;
}

/// The next meeting of each class within a week of [now], soonest first. A
/// class that is still in session counts as upcoming.
List<UpcomingClass> upcomingClasses(
  List<CourseClass> classes,
  DateTime now, {
  int limit = 3,
}) {
  final upcoming = <UpcomingClass>[];
  for (final course in classes) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!course.occursOn(day.weekday)) continue;
      if (!_at(day, course.endTime).isAfter(now)) continue;
      upcoming.add(UpcomingClass(course, _at(day, course.startTime)));
      break;
    }
  }
  upcoming.sort((a, b) => a.start.compareTo(b.start));
  return upcoming.take(limit).toList();
}

/// `Today`, `Tomorrow`, or the weekday of [start].
String upcomingDayLabel(DateTime start, DateTime now) {
  final days = DateTime(
    start.year,
    start.month,
    start.day,
  ).difference(DateTime(now.year, now.month, now.day)).inHours;
  // Rounded so a daylight-saving day still counts as one day.
  return switch ((days / 24).round()) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][start.weekday - 1],
  };
}

DateTime _at(DateTime day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}
