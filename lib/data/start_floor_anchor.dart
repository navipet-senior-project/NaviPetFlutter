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
  static const anchorLead = Duration(seconds: 3);

  final PressureSource source;
  final Duration Function() _clock;

  final DateTime Function() _wallClock;

  final _buffer = <({Duration at, double hPa})>[];
  StreamSubscription<PressureReading>? _sub;
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
    final sub = _sub;
    _sub = null;
    _floor = null;
    _anchor = null;
    _moved = false;
    _failed = false;
    _buffer.clear();
    await sub?.cancel();
  }

  Future<void> dispose() => reset();

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
        _sub?.cancel();
        _sub = null;
      },
    );
    return true;
  }

  /// True once the answer can no longer change: anchored, the sensor failed, or
  /// the anchor deadline passed. Always false before a floor is confirmed.
  bool get resolved =>
      _floor != null &&
      (_anchor != null || _failed || _clock() - _confirmedAt > anchorDeadline);

  /// Null unless a floor is confirmed and the sensor has produced samples.
  IndoorArStartFloor? evidence() {
    final floor = _floor;
    if (floor == null || _failed || _buffer.isEmpty) return null;
    final now = _clock();
    return IndoorArStartFloor(
      floor: floor,
      ageS: (now - _confirmedAt).inMilliseconds / 1000,
      settled: _anchor != null && _settledMedian(now - window, now) != null,
      moved: _moved,
      sampleAgeS: (now - _buffer.last.at).inMilliseconds / 1000,
    );
  }

  void _onReading(PressureReading reading) {
    final age = _wallClock().difference(reading.timestamp);
    final now = _clock();
    final at = now - age;
    if (age.isNegative ||
        age > maxReadingAge ||
        at < _confirmedAt ||
        !reading.hPa.isFinite ||
        (_buffer.isNotEmpty && at <= _buffer.last.at)) {
      return;
    }
    _buffer.add((at: at, hPa: reading.hPa));
    final anchor = _anchor;
    if (anchor != null && (reading.hPa - anchor).abs() >= moveHpa) {
      _moved = true; // latched: going up and back is still a move
    }
    if (anchor == null &&
        at - _confirmedAt >= window &&
        now - _confirmedAt <= anchorDeadline) {
      _anchor = _settledMedian(_confirmedAt, at, lead: anchorLead);
    }
    if (_anchor != null || now - _confirmedAt > anchorDeadline) {
      _buffer.removeWhere((s) => s.at < now - window);
    }
  }

  double? _settledMedian(
    Duration start,
    Duration end, {
    Duration lead = maxGap,
  }) {
    final samples = [
      for (final s in _buffer)
        if (s.at >= start && s.at <= end) s,
    ];
    if (samples.length < minSamples) return null;
    if (samples.first.at - start > lead || end - samples.last.at > maxGap) {
      return null;
    }
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].at - samples[i - 1].at > maxGap) return null;
    }
    final values = [for (final s in samples) s.hPa]..sort();
    if (values.last - values.first > maxRangeHpa) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
}
