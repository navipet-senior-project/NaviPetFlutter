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
  static const maxGap = Duration(seconds: 10);
  static const minSamples = 8;
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

  final _buffer = <({Duration at, double hPa})>[];
  StreamSubscription<PressureReading>? _sub;
  Timer? _expiry;
  String? _floor;
  Duration _confirmedAt = Duration.zero;
  double? _anchor;
  var _moved = false;
  var _failed = false;

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
    _failed = false;
    _buffer.clear();
    await stopped;
  }

  Future<void> dispose() => reset();

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

  void _scheduleStop(Duration now) {
    _expiry?.cancel();
    _expiry = Timer(
      _collectionDeadline - now + const Duration(milliseconds: 1),
      () => unawaited(_stopReading()),
    );
  }

  void _stopIfExpired(Duration now) {
    if (_sub != null && now > _collectionDeadline) {
      unawaited(_stopReading());
    }
  }

  /// Returns false for a blank floor, leaving the previous confirmation.
  bool confirmFloor(String floor) {
    final value = floor.trim();
    if (value.isEmpty) return false;
    _floor = value;
    _confirmedAt = _clock();
    _buffer.clear();
    _anchor = null;
    _moved = false;
    _failed = false;
    _sub ??= source.readings().listen(
      _onReading,
      onError: (Object _) {
        _failed = true;
        unawaited(_stopReading());
      },
    );
    _scheduleStop(_confirmedAt);
    return true;
  }

  /// Whether the hold is complete. Always false before a floor is confirmed.
  bool get resolved {
    _stopIfExpired(_clock());
    return _floor != null && (_anchor != null || _sub == null);
  }

  /// Null unless a floor is confirmed and the sensor has produced samples.
  IndoorArStartFloor? evidence() {
    final floor = _floor;
    if (floor == null || _failed || _buffer.isEmpty) return null;
    final now = _clock();
    _stopIfExpired(now);
    return IndoorArStartFloor(
      floor: floor,
      ageS: (now - _confirmedAt).inMilliseconds / 1000,
      settled:
          _sub != null &&
          _anchor != null &&
          _settledMedian(now - window, now) != null,
      moved: _moved,
      sampleAgeS: (now - _buffer.last.at).inMilliseconds / 1000,
    );
  }

  void _onReading(PressureReading reading) {
    final age = _wallClock().difference(reading.timestamp);
    final now = _clock();
    _stopIfExpired(now);
    if (_sub == null) return;
    final at = now - age;
    if (age.isNegative ||
        age > maxReadingAge ||
        at < _confirmedAt ||
        !reading.hPa.isFinite ||
        (_buffer.isNotEmpty && at <= _buffer.last.at)) {
      return;
    }
    final missingCoverage = _buffer.isEmpty
        ? at - _confirmedAt > anchorLead
        : at - _buffer.last.at > maxGap;
    _buffer.add((at: at, hPa: reading.hPa));
    final anchor = _anchor;
    if (anchor != null && (reading.hPa - anchor).abs() >= moveHpa) {
      _moved = true; // latched: going up and back is still a move
    }
    if (missingCoverage || _moved) {
      unawaited(_stopReading());
      return;
    }
    if (anchor == null && at - _confirmedAt >= window) {
      _anchor = _settledMedian(_confirmedAt, at);
    }
    if (_anchor != null) {
      _buffer.removeWhere((s) => s.at < now - window);
      _scheduleStop(now);
    }
  }

  double? _settledMedian(Duration start, Duration end) {
    final samples = [
      for (final s in _buffer)
        if (s.at >= start && s.at <= end) s,
    ];
    if (samples.length < minSamples) return null;
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
