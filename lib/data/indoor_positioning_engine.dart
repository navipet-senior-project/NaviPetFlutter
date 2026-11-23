import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'floor_pressure.dart';
import 'indoor_particle_filter.dart';
import 'indoor_wifi_fingerprints.dart';

/// Consumes the teammate's confirmed-floor pressure runs without modifying or
/// taking ownership of the recorder. Calibration is relative within each run.
class VecPressureProfile {
  VecPressureProfile.fromRuns(List<FloorPressureRun> runs) {
    final values = <String, List<double>>{};
    for (final run in runs) {
      if (run.samples.isEmpty) continue;
      final perFloor = <String, List<double>>{};
      for (final sample in run.samples) {
        perFloor.putIfAbsent(sample.floor, () => []).add(sample.deltaHpa);
      }
      // The stored delta is relative to the run's first sensor reading. Only
      // runs that visited floor 1 can share a common baseline with other runs.
      if (!perFloor.containsKey('1')) continue;
      final baseline = _median(perFloor['1']!);
      for (final entry in perFloor.entries) {
        values
            .putIfAbsent(entry.key, () => [])
            .add(_median(entry.value) - baseline);
      }
    }
    offsets = {
      for (final entry in values.entries)
        if (entry.value.isNotEmpty) entry.key: _median(entry.value),
    };
  }

  late final Map<String, double> offsets;
  bool get isUsable => offsets.length >= 2;

  FloorBelief? infer(double pressureDeltaHpa, {required String startingFloor}) {
    if (offsets.isEmpty) return null;
    final startingOffset = offsets[startingFloor];
    if (startingOffset == null) return null;
    final scores = offsets.map((floor, expected) {
      final error = pressureDeltaHpa - (expected - startingOffset);
      return MapEntry(floor, math.exp(-(error * error) / (2 * .16 * .16)));
    });
    final closestError = offsets.values
        .map((offset) => (pressureDeltaHpa - (offset - startingOffset)).abs())
        .reduce((a, b) => a < b ? a : b);
    if (closestError > .45) return null;
    final total = scores.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return null;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return FloorBelief(floor: best.key, confidence: best.value / total);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

/// Cross-checks Wi-Fi point estimates with saved pressure calibration and a
/// persistent particle belief. `confirmStartingFloor` anchors live relative
/// pressure for the current outing; it never edits a pressure recorder run.
class IndoorPositioningEngine extends ChangeNotifier {
  IndoorPositioningEngine({
    required this.pressureSource,
    IndoorWifiScanner? wifiScanner,
    IndoorWifiSurveyStore? wifiStore,
    IndoorParticleFilter? filter,
    FloorPressureStore? pressureStore,
  }) : wifiScanner = wifiScanner ?? IndoorWifiScanner(),
       wifiStore = wifiStore ?? IndoorWifiSurveyStore(),
       filter = filter ?? IndoorParticleFilter(),
       pressureStore = pressureStore ?? FloorPressureStore();

  final PressureSource pressureSource;
  final IndoorWifiScanner wifiScanner;
  final IndoorWifiSurveyStore wifiStore;
  final IndoorParticleFilter filter;
  final FloorPressureStore pressureStore;

  StreamSubscription<PressureReading>? _subscription;
  List<IndoorLandpoint> points = [];
  VecPressureProfile? pressureProfile;
  PressureReading? latestPressure;
  double? _pressureBaseline;
  String? _startingFloor;
  WifiFingerprintMatch? lastWifiMatch;
  PressureFailure? pressureFailure;
  bool ready = false;
  bool busy = false;

  FloorBelief? get floorBelief => filter.floorBelief;
  IndoorLandpoint? get likelyPoint => filter.mostLikelyPoint;
  String? get startingFloor => _startingFloor;
  bool get canScanWifi => wifiScanner.isSupported;

  Future<void> initialize(List<IndoorLandpoint> availablePoints) async {
    points = List.of(availablePoints);
    await wifiStore.load();
    await filter.restore(points);
    final runs = await pressureStore.load();
    pressureProfile = VecPressureProfile.fromRuns(runs);
    ready = true;
    notifyListeners();
  }

  void startPressure() {
    if (_subscription != null) return;
    _subscription = pressureSource.readings().listen(
      (reading) {
        latestPressure = reading;
        final startFloor = _startingFloor;
        if (_pressureBaseline == null && startFloor != null) {
          _pressureBaseline = reading.hPa;
        }
        final baseline = _pressureBaseline;
        if (baseline != null && startFloor != null) {
          final pressureBelief = pressureProfile?.infer(
            reading.hPa - baseline,
            startingFloor: startFloor,
          );
          if (pressureBelief != null && pressureBelief.confidence >= .55) {
            final previousFloor = filter.floorBelief?.floor;
            filter.observeFloor(
              pressureBelief.floor,
              confidence: pressureBelief.confidence,
            );
            if (filter.floorBelief?.floor != previousFloor) {
              unawaited(filter.persist());
            }
          }
        }
        notifyListeners();
      },
      onError: (Object error) {
        pressureFailure = error is PressureUnavailable
            ? error.failure
            : classifyPressureError(error).failure;
        notifyListeners();
      },
    );
  }

  Future<void> confirmStartingFloor(String floor) async {
    if (floor.trim().isEmpty) return;
    _startingFloor = floor;
    _pressureBaseline = latestPressure?.hPa;
    filter.seedFloor(floor);
    await filter.persist();
    notifyListeners();
  }

  Future<void> scanAndLocate() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final scan = await wifiScanner.scan();
      filter.predict();
      lastWifiMatch = WifiFingerprintMatcher().estimate(
        scan,
        wifiStore.fingerprints,
      );
      filter.observeWifi(lastWifiMatch);
      await filter.persist();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> captureFingerprint(IndoorLandpoint point) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final scan = await wifiScanner.scan();
      await wifiStore.add(point, scan);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
