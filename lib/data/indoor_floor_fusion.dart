import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Evidence used by the indoor floor estimator. Floors are building-specific
/// labels (for example "1" or "B1"), never inferred from GPS altitude.
enum FloorEvidenceSource { barometer, wifiFingerprint, arSign, userConfirmed }

class FloorEvidence {
  const FloorEvidence({
    required this.floor,
    required this.source,
    this.confidence = 0.8,
  }) : assert(confidence >= 0 && confidence <= 1);

  final String floor;
  final FloorEvidenceSource source;
  final double confidence;
}

class FloorEstimate {
  const FloorEstimate({required this.floor, required this.confidence});
  final String? floor;
  final double confidence;
}

/// A floor-only particle filter. It retains a belief across intermittent Wi-Fi
/// and AR observations, while barometric references are learned only when a
/// person confirms the current floor. Pressure alone is treated as relative
/// height; it cannot identify a floor until at least one reference is saved.
class IndoorFloorFusion {
  IndoorFloorFusion({
    required List<String> floors,
    int particleCount = 256,
    Random? random,
  }) : floors = List.unmodifiable(floors),
       _particleCount = particleCount,
       _random = random ?? Random() {
    if (floors.isEmpty || floors.toSet().length != floors.length) {
      throw ArgumentError('floors must be non-empty and unique');
    }
    if (particleCount < 32) throw ArgumentError('particleCount must be >= 32');
    _resetUniform();
  }

  final List<String> floors;
  final int _particleCount;
  final Random _random;
  final Map<String, double> _pressureByFloor = {};
  late List<int> _particles;
  String? _building;
  double? _lastPressure;
  bool _hasEvidence = false;

  String? get building => _building;
  Map<String, double> get pressureReferences =>
      Map.unmodifiable(_pressureByFloor);

  void setBuilding(String buildingCode) {
    if (buildingCode.trim().isEmpty)
      throw ArgumentError('buildingCode is empty');
    if (_building == buildingCode) return;
    _building = buildingCode;
    _pressureByFloor.clear();
    _lastPressure = null;
    _hasEvidence = false;
    _resetUniform();
  }

  /// Call only after the user explicitly confirms the floor (or a trusted
  /// source confirms it). Averaging reduces short-term HVAC and sensor noise.
  void calibratePressure(String floor, Iterable<double> pascals) {
    _checkFloor(floor);
    final values = pascals
        .where((v) => v.isFinite && v >= 30000 && v <= 120000)
        .toList();
    if (values.isEmpty) throw ArgumentError('No valid pressure samples');
    values.sort();
    _pressureByFloor[floor] = values[values.length ~/ 2];
    observe(
      FloorEvidence(
        floor: floor,
        source: FloorEvidenceSource.userConfirmed,
        confidence: 1,
      ),
    );
  }

  /// Update from a sensor sample in Pa. The pressure profile must be calibrated
  /// in this building; ambient weather changes make global pressure-to-floor
  /// conversion unreliable.
  FloorEstimate addPressure(double pascals) {
    if (!pascals.isFinite || pascals < 30000 || pascals > 120000)
      return estimate;
    _lastPressure = pascals;
    // Do not guess from an incomplete survey: every VEC floor needs a
    // pressure reference before pressure can distinguish them.
    if (_pressureByFloor.length != floors.length) return estimate;
    final nearest = _pressureByFloor.entries.reduce(
      (a, b) => (a.value - pascals).abs() <= (b.value - pascals).abs() ? a : b,
    );
    final gap = _pressureByFloor.values
        .map((p) => (p - pascals).abs())
        .reduce(min);
    // Convert pressure gap to a confidence that decays with about 1 hPa noise.
    final confidence = (exp(-gap / 120) * .8).clamp(.05, .8).toDouble();
    return observe(
      FloorEvidence(
        floor: nearest.key,
        source: FloorEvidenceSource.barometer,
        confidence: confidence,
      ),
    );
  }

  FloorEstimate observe(FloorEvidence evidence) {
    _checkFloor(evidence.floor);
    _hasEvidence = true;
    final trust =
        (switch (evidence.source) {
                  FloorEvidenceSource.barometer => .55,
                  FloorEvidenceSource.wifiFingerprint => .75,
                  FloorEvidenceSource.arSign => .95,
                  FloorEvidenceSource.userConfirmed => 1.0,
                } *
                evidence.confidence)
            .clamp(.01, .999)
            .toDouble();
    // Each particle can stay or move one floor per update. This models stairs
    // and lifts without allowing implausible multi-floor jumps from one sample.
    for (var i = 0; i < _particles.length; i++) {
      if (_random.nextDouble() < .06) {
        final step = _random.nextBool() ? 1 : -1;
        _particles[i] = (_particles[i] + step)
            .clamp(0, floors.length - 1)
            .toInt();
      }
    }
    final target = floors.indexOf(evidence.floor);
    final weights = _particles
        .map(
          (p) => p == target
              ? trust
              : (1 - trust) / (floors.length - 1).clamp(1, floors.length),
        )
        .toList();
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    final cumulative = <double>[];
    var running = 0.0;
    for (final weight in weights) {
      running += weight / total;
      cumulative.add(running);
    }
    _particles = List.generate(_particleCount, (_) {
      final draw = _random.nextDouble();
      var index = cumulative.indexWhere((v) => v >= draw);
      if (index < 0) index = cumulative.length - 1;
      return _particles[index];
    });
    return estimate;
  }

  FloorEstimate get estimate {
    if (!_hasEvidence) return const FloorEstimate(floor: null, confidence: 0);
    final counts = List<int>.filled(floors.length, 0);
    for (final p in _particles) {
      counts[p]++;
    }
    final best = counts.indexOf(counts.reduce(max));
    return FloorEstimate(
      floor: floors[best],
      confidence: counts[best] / _particles.length,
    );
  }

  /// JSON-safe state for offline continuity. Keep keys scoped to a building.
  Map<String, Object?> toJson() => {
    'version': 1,
    'building': _building,
    'floors': floors,
    'pressureByFloor': _pressureByFloor,
    'particles': _particles,
    'lastPressure': _lastPressure,
    'hasEvidence': _hasEvidence,
  };

  Future<void> save() async {
    final code = _building;
    if (code == null) return;
    await SharedPreferences.getInstance().then(
      (prefs) =>
          prefs.setString('indoor_floor_fusion_v1_$code', jsonEncode(toJson())),
    );
  }

  Future<bool> load(String buildingCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('indoor_floor_fusion_v1_$buildingCode');
    if (raw == null) return false;
    try {
      restore(jsonDecode(raw) as Map<String, Object?>);
      return _building == buildingCode;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  void restore(Map<String, Object?> json) {
    if (json['version'] != 1 ||
        json['building'] is! String ||
        json['floors'] is! List ||
        (json['floors'] as List).join('|') != floors.join('|'))
      return;
    _building = json['building'] as String;
    _pressureByFloor
      ..clear()
      ..addAll(
        (json['pressureByFloor'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
    final saved = (json['particles'] as List? ?? [])
        .whereType<num>()
        .map((v) => v.toInt())
        .where((v) => v >= 0 && v < floors.length)
        .toList();
    if (saved.length == _particleCount) _particles = saved;
    _lastPressure = (json['lastPressure'] as num?)?.toDouble();
    _hasEvidence = json['hasEvidence'] == true;
  }

  void _checkFloor(String floor) {
    if (!floors.contains(floor))
      throw ArgumentError.value(floor, 'floor', 'not in this building');
  }

  void _resetUniform() => _particles = List.generate(
    _particleCount,
    (_) => _random.nextInt(floors.length),
  );
}
