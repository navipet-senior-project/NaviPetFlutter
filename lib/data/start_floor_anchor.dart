import 'dart:async';

import 'floor_pressure.dart';
import 'indoor_ar_contract.dart';

/// Barometer evidence that the phone stayed on one level since the user said
/// which floor they stand on. It never names a floor: the floor is always the
/// user's own confirmation, never the destination and never derived from
/// pressure. The rule mirrors Unity's `IndoorFloorBarometer` (report addendum 7).
///
/// The sensor is not read until [confirmFloor]; skipping the question means no
/// collection at all. Every sample is then taken after the confirmation, and
/// the anchor is the settled 20 s window that ends 20 to [anchorDeadline]
/// seconds after the answer, so it covers the answer itself. A phone that
/// moved first, or settled later, gets no anchor and the user must confirm
/// again.
///
/// Nothing but two flags and two ages leaves this class: no absolute or raw
/// pressure, no wall-clock time, no location. Time is the injected monotonic
/// [clock].
///
/// Sensors Plus converts boot-clock timestamps with a cached wall-clock offset.
/// Clock changes or sleep can cause dropped or mis-aged readings and omitted
/// evidence. A clock change before confirmation can hide the start of a fast
/// stair transition and make the previous floor appear valid.
///
/// shortcut: one iPhone, one building, one afternoon of data backs the
/// thresholds; re-measure on a second device and over longer drift.
class StartFloorAnchor {
  StartFloorAnchor({
    required this.source,
    Duration Function()? clock,
    DateTime Function()? wallClock,
  }) : _clock = clock ?? _monotonic(),
       _wallClock = wallClock ?? DateTime.now;

  static const window = Duration(seconds: 20);
  static const _minSampleSpan = Duration(seconds: 18);
  static const maxGap = Duration(seconds: 2);
  static const _timestampTolerance = Duration(milliseconds: 5);
  static const maxRangeHpa = 0.06;
  static const moveHpa = 0.30;

  static const anchorDeadline = Duration(seconds: 22);

  /// A reading whose own timestamp is older than this is a delayed or replayed
  /// delivery and is dropped, never stamped with the arrival time.
  static const maxReadingAge = Duration(seconds: 3);

  /// Longest the first anchor sample may trail the start of its window.
  static const anchorLead = Duration(milliseconds: 1500);

  final PressureSource source;
  final Duration Function() _clock;

  final DateTime Function() _wallClock;

  final _buffer = <({Duration at, DateTime timestamp, double hPa})>[];
  StreamSubscription<PressureReading>? _sub;
  Timer? _expiry;
  String? _floor;
  Duration _confirmedAt = Duration.zero;
  late DateTime _confirmedWallTime;
  double? _anchor;
  var _moved = false;

  static Duration Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// Stops reading and forgets the confirmation, as if never asked.
  Future<void> reset() async {
    final stopped = _stopReading();
    _floor = null;
    _anchor = null;
    _moved = false;
    _buffer.clear();
    await stopped;
  }

  void invalidate() => unawaited(_stopReading());

  Future<void> _stopReading() async {
    _expiry?.cancel();
    _expiry = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  Duration get _collectionDeadline => _anchor == null
      ? _confirmedAt + anchorDeadline
      : _buffer.last.at + maxGap + maxReadingAge;

  Duration get _confirmationExpiry =>
      _confirmedAt + IndoorArStartFloor.maxConfirmationAge;

  void _scheduleStop(Duration now) {
    _expiry?.cancel();
    final deadline = _collectionDeadline + const Duration(milliseconds: 1);
    final stopAt = deadline < _confirmationExpiry
        ? deadline
        : _confirmationExpiry;
    _expiry = Timer(stopAt - now, invalidate);
  }

  void _checkContinuity(Duration now, DateTime wallTime) {
    if (_floor != null &&
        (wallTime.difference(_confirmedWallTime) - (now - _confirmedAt)).abs() >
            _timestampTolerance) {
      invalidate();
      return;
    }
    if (_sub != null &&
        (now > _collectionDeadline || now >= _confirmationExpiry)) {
      invalidate();
    }
  }

  /// Returns false for a blank floor, leaving the previous confirmation.
  bool confirmFloor(String floor) {
    final value = floor.trim();
    if (value.isEmpty) return false;
    _floor = value;
    _confirmedWallTime = _wallClock();
    _confirmedAt = _clock();
    _buffer.clear();
    _anchor = null;
    _moved = false;
    _sub ??= source.readings().listen(
      _onReading,
      onError: (Object _) => invalidate(),
      onDone: invalidate,
    );
    _scheduleStop(_confirmedAt);
    return true;
  }

  /// Whether the hold is complete. Always false before a floor is confirmed.
  bool get resolved {
    final wallTime = _wallClock();
    _checkContinuity(_clock(), wallTime);
    return _floor != null && (_anchor != null || _sub == null);
  }

  /// Evidence from a settled anchor with a live stream and fresh samples.
  IndoorArStartFloor? evidence() {
    final floor = _floor;
    if (floor == null) return null;
    final wallTime = _wallClock();
    final now = _clock();
    _checkContinuity(now, wallTime);
    if (_sub == null || _anchor == null) return null;
    final last = _buffer.last;
    final elapsedAge = now - last.at;
    final timestampAge = wallTime.difference(last.timestamp);
    final sampleAge = elapsedAge > timestampAge ? elapsedAge : timestampAge;
    if (sampleAge > IndoorArStartFloor.maxSampleAge) return null;
    return IndoorArStartFloor(
      floor: floor,
      ageS:
          (now - _confirmedAt).inMicroseconds / Duration.microsecondsPerSecond,
      settled: sampleAge <= maxGap && _settledMedian(now - window, now) != null,
      moved: _moved,
      sampleAgeS: sampleAge.inMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  void _onReading(PressureReading reading) {
    final wallTime = _wallClock();
    final now = _clock();
    _checkContinuity(now, wallTime);
    if (_sub == null) return;
    final timestamp = reading.timestamp;
    final timestampAge = wallTime.difference(timestamp);
    final elapsedAge =
        now - _confirmedAt - timestamp.difference(_confirmedWallTime);
    final age = timestampAge > elapsedAge ? timestampAge : elapsedAge;
    final at = age.isNegative ? now : now - age;
    final last = _buffer.isEmpty ? null : _buffer.last;
    if (timestampAge < -_timestampTolerance ||
        elapsedAge < -_timestampTolerance ||
        age > maxReadingAge ||
        at < _confirmedAt ||
        !reading.hPa.isFinite ||
        (last != null &&
            (at <= last.at || !timestamp.isAfter(last.timestamp)))) {
      return;
    }
    if (last == null
        ? at - _confirmedAt > anchorLead
        : at - last.at > maxGap ||
              timestamp.difference(last.timestamp) > maxGap) {
      invalidate();
      return;
    }
    _buffer.add((at: at, timestamp: timestamp, hPa: reading.hPa));
    final anchor = _anchor;
    if (anchor == null) {
      if (at - _confirmedAt >= window) {
        _anchor = _settledMedian(_confirmedAt, at);
      }
    } else if (!_moved) {
      final median = _settledMedian(at - window, at);
      _moved = median != null && (median - anchor).abs() >= moveHpa;
    }
    if (_anchor != null) {
      _buffer.removeWhere((s) => s.at < at - window);
      _scheduleStop(now);
    }
  }

  double? _settledMedian(Duration start, Duration end) {
    final samples = [
      for (final s in _buffer)
        if (s.at >= start && s.at <= end) s,
    ];
    if (samples.length < 8 ||
        samples.last.at - samples.first.at < _minSampleSpan ||
        samples.last.timestamp.difference(samples.first.timestamp) <
            _minSampleSpan) {
      return null;
    }
    if (samples.first.at - start > maxGap || end - samples.last.at > maxGap) {
      return null;
    }
    final values = [for (final s in samples) s.hPa]..sort();
    if (values.last - values.first > maxRangeHpa) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
}
