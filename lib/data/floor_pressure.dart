import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One barometer reading from the platform (iOS Core Motion `CMAltimeter`,
/// Android `Sensor.TYPE_PRESSURE`).
class PressureReading {
  const PressureReading({required this.hPa, required this.timestamp});

  final double hPa;
  final DateTime timestamp;
}

enum PressureFailure {
  /// No barometer on this device or platform.
  sensorMissing,

  /// The OS refused motion/sensor access (iOS Motion & Fitness switch).
  denied,

  /// Anything else the sensor stream reported.
  error,
}

class PressureUnavailable implements Exception {
  const PressureUnavailable(this.failure, [this.detail]);

  final PressureFailure failure;
  final String? detail;
}

abstract interface class PressureSource {
  /// Emits readings; errors are [PressureUnavailable].
  Stream<PressureReading> readings();
}

class SensorsPlusPressureSource implements PressureSource {
  const SensorsPlusPressureSource();

  @override
  Stream<PressureReading> readings() {
    return barometerEventStream(samplingPeriod: const Duration(seconds: 1))
        .map((e) => PressureReading(hPa: e.pressure, timestamp: e.timestamp))
        .handleError((Object e) => throw classifyPressureError(e));
  }
}

/// shortcut: iOS reports a denied Motion & Fitness switch as `UNAVAILABLE`
/// with Core Motion's localized text, so denial is matched by message. Confirm
/// the wording on a real device; unmatched text falls back to [PressureFailure.error].
PressureUnavailable classifyPressureError(Object e) {
  if (e is MissingPluginException) {
    return const PressureUnavailable(PressureFailure.sensorMissing);
  }
  if (e is PlatformException) {
    final text = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    final failure = switch (e.code) {
      'NO_SENSOR' => PressureFailure.sensorMissing,
      _ when text.contains('authoriz') || text.contains('denied') =>
        PressureFailure.denied,
      _ when text.contains('not available') => PressureFailure.sensorMissing,
      _ => PressureFailure.error,
    };
    return PressureUnavailable(failure, e.code);
  }
  return const PressureUnavailable(PressureFailure.error);
}

/// A pressure change against the first reading of the run, tagged with the
/// floor the user confirmed. No absolute pressure, wall-clock time, location
/// or identifier is kept.
class FloorPressureSample {
  const FloorPressureSample({
    required this.floor,
    required this.elapsedMs,
    required this.deltaHpa,
  });

  factory FloorPressureSample.fromJson(Map<String, dynamic> json) =>
      FloorPressureSample(
        floor: json['floor'] as String,
        elapsedMs: json['elapsedMs'] as int,
        deltaHpa: (json['deltaHpa'] as num).toDouble(),
      );

  final String floor;
  final int elapsedMs;
  final double deltaHpa;

  Map<String, dynamic> toJson() => {
    'floor': floor,
    'elapsedMs': elapsedMs,
    'deltaHpa': deltaHpa,
  };
}

class FloorPressureRun {
  const FloorPressureRun({required this.platform, required this.samples});

  factory FloorPressureRun.fromJson(Map<String, dynamic> json) =>
      FloorPressureRun(
        platform: json['platform'] as String,
        samples: [
          for (final s in json['samples'] as List)
            FloorPressureSample.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String platform;
  final List<FloorPressureSample> samples;

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'samples': [for (final s in samples) s.toJson()],
  };
}

class FloorPressureStore {
  static const _key = 'floor_pressure_runs_v1';

  Future<List<FloorPressureRun>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final r in jsonDecode(raw) as List)
          FloorPressureRun.fromJson(r as Map<String, dynamic>),
      ];
    } on Object {
      return []; // corrupt measurement data is not worth crashing for
    }
  }

  Future<void> save(List<FloorPressureRun> runs) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode([for (final r in runs) r.toJson()]),
    );
    if (!saved) throw StateError('Could not save floor pressure runs');
  }
}

enum RecorderStatus { idle, recording, failed }

/// Records pressure change per user-confirmed floor.
///
/// Platform limits (unverified on device): iOS `CMAltimeter` needs Motion &
/// Fitness access and is only on barometer-equipped iPhones; Android has no
/// permission but only devices with `TYPE_PRESSURE` report; sample rates are
/// OS-chosen (~1 Hz requested). Phone handling, HVAC and weather shift pressure,
/// so only same-run changes are comparable. It never decides which
/// floor the user is on: readings taken before a floor is confirmed are
/// dropped until the user confirms their current floor.
class FloorPressureRecorder extends ChangeNotifier {
  FloorPressureRecorder({
    required this.source,
    required this.store,
    required this.platform,
  });

  final PressureSource source;
  final FloorPressureStore store;

  /// `ios` / `android`, so runs can be compared per platform.
  final String platform;

  RecorderStatus status = RecorderStatus.idle;
  PressureFailure? failure;
  String? confirmedFloor;
  List<FloorPressureRun> runs = const [];

  final _samples = <FloorPressureSample>[];
  StreamSubscription<PressureReading>? _sub;
  PressureReading? _first;
  bool _disposed = false;
  Future<void>? _loading;
  Completer<void>? _clearing;
  Completer<void>? _stopping;
  bool busy = false;
  bool saveFailed = false;
  bool clearFailed = false;
  List<FloorPressureRun>? _clearTargets;

  bool get persistenceFailed => saveFailed || clearFailed;

  int get sampleCount => _samples.length;
  double? get latestDeltaHpa =>
      _samples.isEmpty ? null : _samples.last.deltaHpa;

  Future<void> loadRuns() => _loading ??= _loadRuns();

  Future<void> _loadRuns() async {
    try {
      runs = await store.load();
    } catch (_) {
      _loading = null;
      rethrow;
    }
    if (!_disposed) notifyListeners();
  }

  /// Returns false for a blank floor, leaving the previous one in place.
  bool confirmFloor(String floor) {
    final value = floor.trim();
    if (value.isEmpty) return false;
    confirmedFloor = value;
    notifyListeners();
    return true;
  }

  void start() {
    if (status == RecorderStatus.recording || busy || persistenceFailed) return;
    _samples.clear();
    _first = null;
    confirmedFloor = null;
    failure = null;
    status = RecorderStatus.recording;
    _sub = source.readings().listen(_onReading, onError: _onError);
    notifyListeners();
  }

  /// Ends the run and keeps it if any sample was taken.
  Future<void> stop() async {
    if (_stopping != null) return _stopping!.future;
    final stopping = _stopping = Completer<void>();
    busy = true;
    final subscription = _sub;
    _sub = null;
    if (status == RecorderStatus.recording) status = RecorderStatus.idle;
    if (!_disposed) notifyListeners();
    try {
      await subscription?.cancel();
      await _clearing?.future;
      await loadRuns();
      await _saveRun();
      saveFailed = false;
    } catch (_) {
      saveFailed = true;
    }
    _stopping = null;
    busy = false;
    stopping.complete();
    if (!_disposed) notifyListeners();
  }

  void beginTransition() {
    confirmedFloor = null;
    notifyListeners();
  }

  Future<void> clearRuns() async {
    if (busy || saveFailed) return;
    final clearing = _clearing = Completer<void>();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await loadRuns();
      _clearTargets ??= List.of(runs);
      final remaining = runs
          .where((run) => !_clearTargets!.contains(run))
          .toList();
      await store.save(remaining);
      runs = remaining;
      _clearTargets = null;
      clearFailed = false;
    } catch (_) {
      clearFailed = true;
    }
    _clearing = null;
    clearing.complete();
    if (_stopping == null) busy = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> retryPersistence() async {
    if (busy) return;
    if (saveFailed) await stop();
    if (!saveFailed && clearFailed) await clearRuns();
  }

  String exportJson() => jsonEncode([for (final r in runs) r.toJson()]);

  void _onReading(PressureReading reading) {
    final first = _first ??= reading;
    final floor = confirmedFloor;
    if (floor == null) return;
    _samples.add(
      FloorPressureSample(
        floor: floor,
        elapsedMs: reading.timestamp.difference(first.timestamp).inMilliseconds,
        deltaHpa: double.parse((reading.hPa - first.hPa).toStringAsFixed(3)),
      ),
    );
    notifyListeners();
  }

  void _onError(Object error) {
    failure = error is PressureUnavailable
        ? error.failure
        : classifyPressureError(error).failure;
    status = RecorderStatus.failed;
    // Samples gathered before the failure are still real measurements.
    stop();
  }

  Future<void> _saveRun() async {
    if (_samples.isEmpty) return;
    final updated = [
      ...runs,
      FloorPressureRun(platform: platform, samples: List.of(_samples)),
    ];
    await store.save(updated);
    runs = updated;
    _samples.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
