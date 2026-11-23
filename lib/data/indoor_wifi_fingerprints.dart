import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IndoorLandpoint {
  const IndoorLandpoint({
    required this.id,
    required this.floor,
    required this.type,
    required this.x,
    required this.y,
    required this.z,
  });

  final String id;
  final String floor;
  final String type;
  final double x;
  final double y;
  final double z;
}

class WifiAccessPointReading {
  const WifiAccessPointReading({
    required this.bssid,
    required this.rssiDbm,
    required this.frequencyMhz,
  });

  final String bssid;
  final int rssiDbm;
  final int frequencyMhz;

  Map<String, Object> toJson() => {
    'bssid': bssid,
    'rssiDbm': rssiDbm,
    'frequencyMhz': frequencyMhz,
  };

  factory WifiAccessPointReading.fromJson(Map<String, dynamic> json) =>
      WifiAccessPointReading(
        bssid: json['bssid'] as String,
        rssiDbm: (json['rssiDbm'] as num).toInt(),
        frequencyMhz: (json['frequencyMhz'] as num).toInt(),
      );
}

class WifiScanSnapshot {
  const WifiScanSnapshot({
    required this.capturedAt,
    required this.accessPoints,
  });

  final DateTime capturedAt;
  final List<WifiAccessPointReading> accessPoints;
}

/// Android-only foreground scan. The AP positions are not required because
/// this feature matches RSSI fingerprints recorded at Unity landpoints.
class IndoorWifiScanner {
  static const _channel = MethodChannel('navipet/indoor_wifi_scan');

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<WifiScanSnapshot> scan() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Nearby Wi-Fi scans are available on Android only.',
      );
    }
    final result = await _channel.invokeMapMethod<String, Object?>('scan');
    if (result == null || result['fresh'] != true) {
      throw StateError('Android did not return a fresh Wi-Fi scan.');
    }
    final raw = result['accessPoints'];
    final epochMs = result['capturedAtEpochMs'];
    if (raw is! List || epochMs is! num) {
      throw const FormatException('Malformed Wi-Fi scan response.');
    }
    final readings = raw
        .whereType<Map>()
        .map(
          (value) =>
              WifiAccessPointReading.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
    if (readings.isEmpty) {
      throw StateError(
        'The scan had no visible access points. Check location permission and Location services.',
      );
    }
    return WifiScanSnapshot(
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        epochMs.toInt(),
        isUtc: true,
      ),
      accessPoints: readings,
    );
  }
}

class WifiFingerprint {
  const WifiFingerprint({required this.point, required this.scan});

  final IndoorLandpoint point;
  final WifiScanSnapshot scan;

  Map<String, Object?> toJson() => {
    'point': {
      'id': point.id,
      'floor': point.floor,
      'type': point.type,
      'x': point.x,
      'y': point.y,
      'z': point.z,
    },
    'capturedAt': scan.capturedAt.toUtc().toIso8601String(),
    'accessPoints': scan.accessPoints.map((ap) => ap.toJson()).toList(),
  };

  factory WifiFingerprint.fromJson(Map<String, dynamic> json) {
    final pointJson = json['point'] as Map<String, dynamic>;
    final rawAps = json['accessPoints'] as List<dynamic>;
    return WifiFingerprint(
      point: IndoorLandpoint(
        id: pointJson['id'] as String,
        floor: pointJson['floor'] as String,
        type: pointJson['type'] as String,
        x: (pointJson['x'] as num).toDouble(),
        y: (pointJson['y'] as num).toDouble(),
        z: (pointJson['z'] as num).toDouble(),
      ),
      scan: WifiScanSnapshot(
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        accessPoints: rawAps
            .map(
              (entry) => WifiAccessPointReading.fromJson(
                entry as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class IndoorWifiSurveyStore {
  static const key = 'vec_wifi_fingerprints_v1';

  List<WifiFingerprint> fingerprints = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      fingerprints = (json['fingerprints'] as List<dynamic>)
          .map(
            (entry) => WifiFingerprint.fromJson(entry as Map<String, dynamic>),
          )
          .toList(growable: true);
    } on Object {
      fingerprints = [];
    }
  }

  Future<void> add(IndoorLandpoint point, WifiScanSnapshot scan) async {
    fingerprints.add(WifiFingerprint(point: point, scan: scan));
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'schemaVersion': 1,
        'building': 'VEC',
        'coordinateFrame': 'multiset-mapset',
        'fingerprints': fingerprints.map((fp) => fp.toJson()).toList(),
      }),
    );
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'building': 'VEC',
    'coordinateFrame': 'multiset-mapset',
    'fingerprints': fingerprints.map((fp) => fp.toJson()).toList(),
  });
}

class WifiFingerprintMatch {
  const WifiFingerprintMatch({
    required this.pointId,
    required this.floor,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
    required this.rssiDistance,
  });

  final String pointId;
  final String floor;
  final double x;
  final double y;
  final double z;
  final double confidence;
  final double rssiDistance;
}

/// Weighted k-nearest fingerprint matching. Missing APs use the noise-floor
/// value; records with fewer than two shared APs are ignored.
class WifiFingerprintMatcher {
  const WifiFingerprintMatcher({this.neighbors = 5, this.noiseFloorDbm = -100});

  final int neighbors;
  final int noiseFloorDbm;

  WifiFingerprintMatch? estimate(
    WifiScanSnapshot live,
    List<WifiFingerprint> training,
  ) {
    final liveRssi = {for (final ap in live.accessPoints) ap.bssid: ap.rssiDbm};
    if (liveRssi.length < 2 || training.isEmpty) return null;
    final distances = <({WifiFingerprint fingerprint, double distance})>[];
    for (final fingerprint in training) {
      final known = {
        for (final ap in fingerprint.scan.accessPoints) ap.bssid: ap.rssiDbm,
      };
      final shared = liveRssi.keys.where(known.containsKey).length;
      if (shared < 2) continue;
      final keys = {...liveRssi.keys, ...known.keys};
      final squared = keys.fold<double>(0, (sum, bssid) {
        final a = liveRssi[bssid] ?? noiseFloorDbm;
        final b = known[bssid] ?? noiseFloorDbm;
        return sum + (a - b) * (a - b);
      });
      distances.add((
        fingerprint: fingerprint,
        distance: math.sqrt(squared / keys.length),
      ));
    }
    if (distances.isEmpty) return null;
    distances.sort((a, b) => a.distance.compareTo(b.distance));
    final selected = distances.take(neighbors).toList(growable: false);
    final weights = selected.map((entry) => 1 / (entry.distance + 1)).toList();
    final total = weights.fold<double>(0, (sum, weight) => sum + weight);
    final floors = <String, double>{};
    final points = <String, ({IndoorLandpoint point, double weight})>{};
    for (var i = 0; i < selected.length; i++) {
      final fp = selected[i].fingerprint;
      final weight = weights[i];
      floors.update(
        fp.point.floor,
        (value) => value + weight,
        ifAbsent: () => weight,
      );
      points.update(
        fp.point.id,
        (value) => (point: value.point, weight: value.weight + weight),
        ifAbsent: () => (point: fp.point, weight: weight),
      );
    }
    final floor = floors.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final sameFloor = points.values
        .where((entry) => entry.point.floor == floor.key)
        .toList();
    final point = sameFloor
        .reduce((a, b) => a.weight >= b.weight ? a : b)
        .point;
    final weightForFloor = floor.value / total;
    final signalFit = math.exp(-selected.first.distance / 35);
    return WifiFingerprintMatch(
      pointId: point.id,
      floor: point.floor,
      x: point.x,
      y: point.y,
      z: point.z,
      confidence: (weightForFloor * signalFit).clamp(0, 1).toDouble(),
      rssiDistance: selected.first.distance,
    );
  }
}
