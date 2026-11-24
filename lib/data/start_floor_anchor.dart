import 'dart:async';

import 'floor_pressure.dart';
import 'indoor_ar_contract.dart';

/// Barometer evidence that the phone stayed on one level since the user said
/// which floor they stand on. It never names a floor: the floor is always the
/// user's own confirmation, never the destination and never derived from
/// pressure. The rule mirrors Unity's `IndoorFloorBarometer` (report addendum 7).
///
/// Nothing but two flags and an age leaves this class: no absolute or raw
/// pressure, no wall-clock time, no location. Time is the injected monotonic
/// [clock]. A settled window may include samples from just before the
/// confirmation; walking would make it unsettled, so a still phone is the only
/// way to anchor.
///
/// shortcut: one iPhone, one building, one afternoon of data backs the
/// thresholds; re-measure on a second device and over longer drift.
class StartFloorAnchor {
  StartFloorAnchor({required this.source, Duration Function()? clock})
    : _clock = clock ?? _monotonic();

  static const window = Duration(seconds: 20);
  static const maxGap = Duration(seconds: 10);
  static const minSamples = 8;
  static const maxRangeHpa = 0.06;
  static const moveHpa = 0.30;

  final PressureSource source;
  final Duration Function() _clock;

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

  /// Starts listening. Safe to call once; a sensor error ends the evidence.
  void start() {
    _sub ??= source.readings().listen(
      _onReading,
      onError: (Object _) {
        _failed = true;
        _sub?.cancel();
      },
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _buffer.clear();
  }

  /// Returns false for a blank floor, leaving the previous confirmation.
  bool confirmFloor(String floor) {
    final value = floor.trim();
    if (value.isEmpty) return false;
    _floor = value;
    _confirmedAt = _clock();
    _anchor = null;
    _moved = false;
    _evaluate();
    return true;
  }

  /// Null unless a floor is confirmed and the sensor has produced samples.
  IndoorArStartFloor? evidence() {
    final floor = _floor;
    if (floor == null || _failed || _buffer.isEmpty) return null;
    final now = _clock();
    _evaluate();
    return IndoorArStartFloor(
      floor: floor,
      ageS: (now - _confirmedAt).inMilliseconds / 1000,
      settled: _settledMedian(now) != null,
      moved: _moved,
      sampleAgeS: (now - _buffer.last.at).inMilliseconds / 1000,
    );
  }

  void _onReading(PressureReading reading) {
    final now = _clock();
    _buffer.add((at: now, hPa: reading.hPa));
    _buffer.removeWhere((s) => s.at <= now - window);
    _evaluate();
  }

  void _evaluate() {
    if (_floor == null) return;
    final median = _settledMedian(_clock());
    if (median == null) return;
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = median;
    } else if ((median - anchor).abs() >= moveHpa) {
      _moved = true; // latched: going up and back is still a move
    }
  }

  /// Median of the last [window] if it is dense, gap-free and flat, else null.
  double? _settledMedian(Duration now) {
    final start = now - window;
    final samples = [
      for (final s in _buffer)
        if (s.at > start && s.at <= now) s,
    ];
    if (samples.length < minSamples) return null;
    if (samples.first.at - start > maxGap || now - samples.last.at > maxGap) {
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
