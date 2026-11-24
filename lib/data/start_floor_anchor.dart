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
/// The floor question is skippable. It only helps when Unity is a paired build
/// that contains the floor policy (NaviPetUnity PR 37 or later). An older Unity
/// build ignores the extra fields and behaves as before; Flutter cannot detect
/// which build it launches and claims no version capability.
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
  static const _minSampleSpacing = Duration(milliseconds: 500);
  static const _maxAnchorGap = Duration(seconds: 2);
  static const _timestampTolerance = Duration(milliseconds: 5);
  static const maxRangeHpa = 0.06;
  static const moveHpa = 0.30;
  static const _pressureRoundoffHpa = 1e-9;

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

  Duration get _confirmationExpiry =>
      _confirmedAt + IndoorArStartFloor.maxConfirmationAge;

  void _scheduleStop(Duration now) {
    _expiry?.cancel();
    final stopAt = _anchor == null
        ? _confirmedAt + anchorDeadline + const Duration(milliseconds: 1)
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
        (now >= _confirmationExpiry ||
            (_anchor == null && now - _confirmedAt > anchorDeadline))) {
      invalidate();
    }
  }

  /// Returns false for an invalid floor, leaving the previous confirmation.
  bool confirmFloor(String floor) {
    final value = IndoorArStartFloor.normalizeFloor(floor);
    if (value == null) return false;
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

  /// Evidence from settled anchor and current windows with fresh samples.
  IndoorArStartFloor? evidence() {
    final floor = _floor;
    if (floor == null) return null;
    final wallTime = _wallClock();
    final now = _clock();
    _checkContinuity(now, wallTime);
    final anchor = _anchor;
    if (_sub == null || anchor == null || _buffer.isEmpty) return null;
    final last = _buffer.last;
    final elapsedAge = now - last.at;
    final timestampAge = wallTime.difference(last.timestamp);
    final sampleAge = elapsedAge > timestampAge ? elapsedAge : timestampAge;
    if (sampleAge > IndoorArStartFloor.maxSampleAge) return null;
    final median = _settledMedian(now - window, now);
    if (median == null) return null;
    return IndoorArStartFloor(
      floor: floor,
      ageS:
          (now - _confirmedAt).inMicroseconds / Duration.microsecondsPerSecond,
      moved: _moved || _hasMoved(median, anchor),
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
    final anchor = _anchor;
    final last = _buffer.isEmpty ? null : _buffer.last;
    if (timestampAge < -_timestampTolerance ||
        elapsedAge < -_timestampTolerance ||
        age > maxReadingAge ||
        at < _confirmedAt ||
        !reading.hPa.isFinite) {
      return;
    }
    if (last == null) {
      if (anchor == null && at - _confirmedAt > anchorLead) {
        invalidate();
        return;
      }
    } else {
      final elapsedGap = at - last.at;
      final timestampGap = timestamp.difference(last.timestamp);
      if (elapsedGap <= Duration.zero || timestampGap <= Duration.zero) {
        if (anchor != null) {
          _buffer.clear();
        } else if (elapsedGap.isNegative || timestampGap.isNegative) {
          invalidate();
        }
        return;
      }
      final maxGap = anchor == null
          ? _maxAnchorGap
          : IndoorArStartFloor.maxSampleAge;
      if (elapsedGap > maxGap || timestampGap > maxGap) {
        if (anchor == null) {
          invalidate();
          return;
        }
        _buffer.clear();
      }
      if (elapsedGap < _minSampleSpacing || timestampGap < _minSampleSpacing) {
        return;
      }
    }
    _buffer.add((at: at, timestamp: timestamp, hPa: reading.hPa));
    if (anchor == null) {
      if (at - _confirmedAt >= window) {
        _anchor = _settledMedian(_confirmedAt, at);
        if (_anchor != null) _scheduleStop(now);
      }
    } else if (!_moved) {
      final median = _settledMedian(at - window, at);
      _moved = median != null && _hasMoved(median, anchor);
    }
    if (_anchor != null) {
      _buffer.removeWhere((s) => s.at < at - window);
    }
  }

  static bool _hasMoved(double median, double anchor) =>
      (median - anchor).abs() >= moveHpa - _pressureRoundoffHpa;

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
    final values = [for (final s in samples) s.hPa]..sort();
    if (values.last - values.first > maxRangeHpa + _pressureRoundoffHpa) {
      return null;
    }
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
}
