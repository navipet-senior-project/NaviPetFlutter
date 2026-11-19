import 'dart:async';

import 'indoor_floor_fusion.dart';
import 'indoor_pressure_stream.dart';

/// Connects live pressure readings and external floor evidence to the VEC
/// fusion model. Wi-Fi fingerprints and AR sign recognition feed through
/// [observe], keeping their platform-specific collection separate.
class IndoorFloorTracker {
  IndoorFloorTracker({
    required this.buildingCode,
    required this.fusion,
    required this.pressureStream,
  });

  final String buildingCode;
  final IndoorFloorFusion fusion;
  final IndoorPressureStream pressureStream;
  final _estimates = StreamController<FloorEstimate>.broadcast();
  final List<double> _recentPressure = [];
  StreamSubscription<double>? _subscription;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<FloorEstimate> get estimates => _estimates.stream;
  FloorEstimate get current => fusion.estimate;
  int get pressureSampleCount => _recentPressure.length;

  Future<void> start() async {
    if (fusion.building != buildingCode) {
      final restored = await fusion.load(buildingCode);
      if (!restored) fusion.setBuilding(buildingCode);
    }
    await _subscription?.cancel();
    _subscription = pressureStream.pascals.listen((pressure) {
      _recentPressure.add(pressure);
      if (_recentPressure.length > 40) _recentPressure.removeAt(0);
      _estimates.add(fusion.addPressure(pressure));
      final now = DateTime.now();
      if (now.difference(_lastSave) >= const Duration(seconds: 15)) {
        _lastSave = now;
        unawaited(fusion.save());
      }
    }, onError: (_) {
      // A missing pressure sensor is an expected capability fallback.
    });
  }

  /// User confirms the floor after reaching a known room or other landmark.
  /// Recent readings are averaged by median and stored as this building's
  /// local reference. Do not call this from an unconfirmed guess.
  Future<void> confirmFloor(String floor) async {
    if (_recentPressure.length < 5) {
      throw StateError('Wait for at least five pressure readings first.');
    }
    fusion.calibratePressure(floor, _recentPressure);
    _estimates.add(fusion.estimate);
    await fusion.save();
  }

  Future<void> observe(FloorEvidence evidence) async {
    _estimates.add(fusion.observe(evidence));
    await fusion.save();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _estimates.close();
  }
}
