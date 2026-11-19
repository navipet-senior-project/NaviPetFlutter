import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

class WifiScanSnapshot {
  const WifiScanSnapshot({
    required this.capturedAt,
    required this.accessPoints,
  });

  final DateTime capturedAt;
  final List<WifiAccessPointReading> accessPoints;
}

/// Android-only foreground Wi-Fi scan bridge. iOS does not expose general
/// nearby-network scans to apps.
class IndoorWifiSurveySource {
  static const _channel = MethodChannel('navipet/indoor_wifi_survey');

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<WifiScanSnapshot> scan() async {
    if (!isSupported) throw UnsupportedError('Wi-Fi survey is Android-only.');
    final response = await _channel.invokeMapMethod<String, Object?>('scan');
    if (response == null || response['fresh'] != true) {
      throw StateError(
        'Android did not return a fresh Wi-Fi scan. Try again later.',
      );
    }
    final rawPoints = response['accessPoints'];
    final capturedAtValue = response['capturedAtEpochMs'];
    final capturedAt = capturedAtValue is num
        ? DateTime.fromMillisecondsSinceEpoch(
            capturedAtValue.toInt(),
            isUtc: true,
          )
        : null;
    if (rawPoints is! List || capturedAt == null) {
      throw const FormatException('Malformed Wi-Fi scan response.');
    }
    final points = rawPoints
        .whereType<Map>()
        .map(
          (point) => WifiAccessPointReading(
            bssid: point['bssid'] as String,
            rssiDbm: (point['rssiDbm'] as num).toInt(),
            frequencyMhz: (point['frequencyMhz'] as num).toInt(),
          ),
        )
        .toList(growable: false);
    return WifiScanSnapshot(capturedAt: capturedAt, accessPoints: points);
  }
}

class WifiFingerprintSurveyRecord {
  const WifiFingerprintSurveyRecord({
    required this.pointId,
    required this.floor,
    required this.x,
    required this.y,
    required this.z,
    required this.capturedAt,
    required this.accessPoints,
  });

  final String pointId;
  final String floor;
  final double x;
  final double y;
  final double z;
  final DateTime capturedAt;
  final List<WifiAccessPointReading> accessPoints;

  Map<String, Object?> toJson() => {
    'pointId': pointId,
    'floor': floor,
    'position': {'x': x, 'y': y, 'z': z},
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'accessPoints': accessPoints.map((point) => point.toJson()).toList(),
  };
}

/// Stores field-survey records on the device and exports a versioned JSON file
/// payload that can be copied for the later fingerprint-matcher work.
class IndoorWifiSurveyStore {
  static const _key = 'vec_wifi_fingerprint_survey_v1';

  List<WifiFingerprintSurveyRecord> records = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final document = jsonDecode(raw) as Map<String, dynamic>;
      final items = document['records'] as List<dynamic>;
      records = items
          .map((item) {
            final json = item as Map<String, dynamic>;
            final position = json['position'] as Map<String, dynamic>;
            final points = (json['accessPoints'] as List<dynamic>)
                .map((entry) {
                  final point = entry as Map<String, dynamic>;
                  return WifiAccessPointReading(
                    bssid: point['bssid'] as String,
                    rssiDbm: (point['rssiDbm'] as num).toInt(),
                    frequencyMhz: (point['frequencyMhz'] as num).toInt(),
                  );
                })
                .toList(growable: false);
            return WifiFingerprintSurveyRecord(
              pointId: json['pointId'] as String,
              floor: json['floor'] as String,
              x: (position['x'] as num).toDouble(),
              y: (position['y'] as num).toDouble(),
              z: (position['z'] as num).toDouble(),
              capturedAt: DateTime.parse(json['capturedAt'] as String),
              accessPoints: points,
            );
          })
          .toList(growable: true);
    } on FormatException {
      records = [];
    } on TypeError {
      records = [];
    }
  }

  Future<void> add({
    required String pointId,
    required int floor,
    required double x,
    required double y,
    required double z,
    required WifiScanSnapshot scan,
  }) async {
    records.add(
      WifiFingerprintSurveyRecord(
        pointId: pointId,
        floor: '$floor',
        x: x,
        y: y,
        z: z,
        capturedAt: scan.capturedAt,
        accessPoints: scan.accessPoints,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(exportDocument()));
  }

  Map<String, Object?> exportDocument() => {
    'schemaVersion': 1,
    'building': 'VEC',
    'coordinateFrame': 'multiset-mapset',
    'records': records.map((record) => record.toJson()).toList(),
  };

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(exportDocument());
}
