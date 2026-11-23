import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'indoor_wifi_fingerprints.dart';

class FloorBelief {
  const FloorBelief({required this.floor, required this.confidence});
  final String floor;
  final double confidence;
}

/// A discrete particle filter over surveyed VEC landpoints. Each particle is a
/// possible current landmark; observations reweight and resample that set.
class IndoorParticleFilter {
  IndoorParticleFilter({math.Random? random, this.particleCount = 256})
    : _random = random ?? math.Random();

  static const _storageKey = 'vec_indoor_particle_belief_v1';
  final math.Random _random;
  final int particleCount;
  List<IndoorLandpoint> _points = const [];
  final List<String> _particles = [];

  Map<String, double> get pointBelief {
    if (_particles.isEmpty) return const {};
    final counts = <String, int>{};
    for (final id in _particles) {
      counts.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    return {
      for (final entry in counts.entries)
        entry.key: entry.value / _particles.length,
    };
  }

  Future<void> restore(List<IndoorLandpoint> points) async {
    _points = [
      ...points,
      for (final floor in ['1', '2', '3', '4', '5'])
        if (!points.any((point) => point.floor == floor))
          IndoorLandpoint(
            id: '__floor_prior_$floor',
            floor: floor,
            type: 'floor_prior',
            x: 0,
            y: 0,
            z: 0,
          ),
    ];
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final savedWeights = saved['weights'] as Map<String, dynamic>;
      final distribution = <String, double>{
        for (final entry in savedWeights.entries)
          if (_points.any((point) => point.id == entry.key))
            entry.key: (entry.value as num).toDouble(),
      };
      _particles
        ..clear()
        ..addAll(_sample(distribution, particleCount));
    } on Object {
      _particles.clear();
    }
  }

  void seedFloor(String floor) {
    final candidates = _points.where((point) => point.floor == floor).toList();
    if (candidates.isEmpty) return;
    _particles
      ..clear()
      ..addAll(
        List.generate(
          particleCount,
          (_) => candidates[_random.nextInt(candidates.length)].id,
        ),
      );
  }

  /// Propagate particles through nearby landmarks. Staying put is more likely;
  /// vertical movement can occur between corresponding stairs/elevator points.
  void predict({double movementProbability = .24}) {
    if (_particles.isEmpty) return;
    for (var i = 0; i < _particles.length; i++) {
      final current = _point(_particles[i]);
      if (current == null ||
          current.type == 'floor_prior' ||
          _random.nextDouble() >= movementProbability) {
        continue;
      }
      final neighbors = _points
          .where(
            (candidate) =>
                candidate.id != current.id &&
                (candidate.floor == current.floor
                    ? _distance(current, candidate) <= 12
                    : _isVerticalTransition(current, candidate)),
          )
          .toList();
      if (neighbors.isNotEmpty) {
        _particles[i] = neighbors[_random.nextInt(neighbors.length)].id;
      }
    }
  }

  void observeWifi(WifiFingerprintMatch? match) {
    if (match == null || _points.isEmpty) return;
    if (_particles.isEmpty) seedFloor(match.floor);
    final likelihoods = <String, double>{};
    for (final point in _points) {
      if (point.type == 'floor_prior') {
        likelihoods[point.id] = point.floor == match.floor ? 1.0 : .001;
        continue;
      }
      final distance = math.sqrt(
        math.pow(point.x - match.x, 2) +
            math.pow(point.y - match.y, 2) +
            math.pow(point.z - match.z, 2),
      );
      likelihoods[point.id] =
          (point.floor == match.floor ? 1.0 : .01) * math.exp(-distance / 5.0) +
          1e-9;
    }
    _applyObservation(likelihoods);
  }

  void observeFloor(String floor, {double confidence = .75}) {
    if (_points.where((point) => point.floor == floor).isEmpty) return;
    if (_particles.isEmpty) seedFloor(floor);
    final trust = confidence.clamp(.05, .99).toDouble();
    final otherFloorCount =
        (_points.map((point) => point.floor).toSet().length - 1).clamp(1, 5);
    _applyObservation({
      for (final point in _points)
        point.id: point.floor == floor
            ? trust
            : (1 - trust) / otherFloorCount + 1e-9,
    });
  }

  FloorBelief? get floorBelief {
    final weights = <String, double>{};
    for (final entry in pointBelief.entries) {
      final point = _point(entry.key);
      if (point != null) {
        weights.update(
          point.floor,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    if (weights.isEmpty) return null;
    final best = weights.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return FloorBelief(floor: best.key, confidence: best.value);
  }

  IndoorLandpoint? get mostLikelyPoint {
    final weights = pointBelief;
    if (weights.isEmpty) return null;
    final ranked = weights.entries
        .where((entry) => _point(entry.key)?.type != 'floor_prior')
        .toList();
    if (ranked.isEmpty) return null;
    final best = ranked.reduce((a, b) => a.value >= b.value ? a : b);
    return _point(best.key);
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final belief = floorBelief;
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'building': 'VEC',
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'floor': belief?.floor,
        'confidence': belief?.confidence,
        'weights': pointBelief,
      }),
    );
  }

  void _applyObservation(Map<String, double> likelihoods) {
    if (_points.isEmpty) return;
    final prior = pointBelief;
    final floorCounts = <String, int>{};
    for (final point in _points) {
      floorCounts.update(point.floor, (count) => count + 1, ifAbsent: () => 1);
    }
    final floorCount = floorCounts.length;
    const exploration = .2;
    final weighted = <String, double>{};
    for (final point in _points) {
      final uniformByFloor = 1 / (floorCount * floorCounts[point.floor]!);
      final priorWeight =
          (prior[point.id] ?? 0) * (1 - exploration) +
          uniformByFloor * exploration;
      weighted[point.id] = priorWeight * (likelihoods[point.id] ?? 1e-9);
    }
    _particles
      ..clear()
      ..addAll(_sample(weighted, particleCount));
  }

  List<String> _sample(Map<String, double> weights, int count) {
    final valid = weights.entries
        .where((entry) => entry.value > 0 && entry.value.isFinite)
        .toList();
    if (valid.isEmpty || count <= 0) return [];
    final total = valid.fold<double>(0, (sum, entry) => sum + entry.value);
    final step = total / count;
    var threshold = _random.nextDouble() * step;
    var cumulative = valid.first.value;
    var index = 0;
    final result = <String>[];
    for (var sample = 0; sample < count; sample++) {
      while (threshold > cumulative && index < valid.length - 1) {
        index++;
        cumulative += valid[index].value;
      }
      result.add(valid[index].key);
      threshold += step;
    }
    return result;
  }

  IndoorLandpoint? _point(String id) {
    for (final point in _points) {
      if (point.id == id) return point;
    }
    return null;
  }

  static double _distance(IndoorLandpoint a, IndoorLandpoint b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.z - b.z, 2));

  static bool _isVerticalTransition(IndoorLandpoint a, IndoorLandpoint b) =>
      const {'stairs', 'elevator'}.contains(a.type) &&
      const {'stairs', 'elevator'}.contains(b.type) &&
      _distance(a, b) <= 4;
}
