import 'dart:async';

import 'floor_pressure.dart';
import 'indoor_ar_contract.dart';

/// Tracks pressure relative to the floor selected by the user. A settled window
/// later in the session cannot replace the initial hold, since the floor answer
/// applies to the moment of confirmation.
///
/// Sensors Plus converts boot-clock timestamps with a cached wall-clock offset.
/// Clock changes or sleep can cause dropped or mis-aged readings and omitted
/// evidence. A clock change before confirmation can hide the start of a fast
/// stair transition and make the previous floor appear valid.
///
/// See `docs/indoor-ar-floor-evidence.md` for eligibility and calibration limits.
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
  static const _captureGapLimit = Duration(seconds: 10);
  static const _timestampTolerance = Duration(milliseconds: 5);
  static const maxRangeHpa = 0.06;
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
  // Keep Unity's floor veto disabled after a settled trip away, even if the
  // current median returns to the anchor.
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
  ///
  /// [requestSentAtBootS] is the device boot clock read immediately before this
  /// call, so the ages computed here are never older than the stamp.
  IndoorArStartFloor? evidence({double? requestSentAtBootS}) {
    final floor = _floor;
    if (floor == null) return null;
    final wallTime = _wallClock();
    final now = _clock();
    _checkContinuity(now, wallTime);
    final anchor = _anchor;
    if (_sub == null || anchor == null || _buffer.isEmpty) return null;
    _latchMovementBetweenCaptures(now, anchor);
    final last = _buffer.last;
    final elapsedAge = now - last.at;
    final timestampAge = wallTime.difference(last.timestamp);
    final sampleAge = elapsedAge > timestampAge ? elapsedAge : timestampAge;
    if (sampleAge > IndoorArStartFloor.maxSampleAge) return null;
    final median = _settledMedian(now - window, now);
    if (median == null) return null;
    _moved = _moved || _hasMoved(median, anchor);
    return IndoorArStartFloor(
      floor: floor,
      ageS:
          (now - _confirmedAt).inMicroseconds / Duration.microsecondsPerSecond,
      moved: _moved,
      sampleAgeS: sampleAge.inMicroseconds / Duration.microsecondsPerSecond,
      deltaHpa: median - anchor,
      requestSentAtBootS: requestSentAtBootS,
    );
  }

  void _onReading(PressureReading reading) {
    final wallTime = _wallClock();
    final now = _clock();
    _checkContinuity(now, wallTime);
    if (_sub == null) return;
    final timestamp = reading.timestamp;
    final last = _buffer.isEmpty ? null : _buffer.last;
    final timestampGap = timestamp.difference(last?.timestamp ?? timestamp);
    if (last != null && timestampGap.abs() < _minSampleSpacing) {
      return;
    }
    final timestampAge = wallTime.difference(timestamp);
    final elapsedAge =
        now - _confirmedAt - timestamp.difference(_confirmedWallTime);
    final age = timestampAge > elapsedAge ? timestampAge : elapsedAge;
    final at = age.isNegative ? now : now - age;
    final anchor = _anchor;
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
      if (elapsedGap.abs() < _minSampleSpacing) return;
      final backward = elapsedGap.isNegative || timestampGap.isNegative;
      if (anchor != null) {
        _latchMovementBetweenCaptures(backward ? now : at, anchor);
      }
      if (backward) {
        if (anchor != null) {
          _buffer.clear();
        } else {
          invalidate();
        }
        return;
      }
      final gap = elapsedGap > timestampGap ? elapsedGap : timestampGap;
      final exceededGap = anchor == null
          ? gap > _maxAnchorGap
          : gap >= _captureGapLimit;
      if (exceededGap) {
        if (anchor == null) {
          invalidate();
          return;
        }
        _buffer.clear();
      }
    }
    _buffer.add((at: at, timestamp: timestamp, hPa: reading.hPa));
    if (anchor == null) {
      if (at - _confirmedAt >= window &&
          _settledMedian(_confirmedAt, at) != null) {
        _anchor = _settledMedian(at - window, at);
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

  void _latchMovementBetweenCaptures(Duration end, double anchor) {
    if (_moved) return;
    for (final sample in _buffer) {
      if (sample.at >= end - window) break;
      final start = sample.at + const Duration(microseconds: 1);
      final median = _settledMedian(start, start + window);
      if (median != null && _hasMoved(median, anchor)) {
        _moved = true;
        return;
      }
    }
  }

  static bool _hasMoved(double median, double anchor) =>
      (median - anchor).abs() >=
      IndoorArStartFloor.moveHpa - _pressureRoundoffHpa;

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
    if (values.last - values.first >= maxRangeHpa - _pressureRoundoffHpa) {
      return null;
    }
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
}
