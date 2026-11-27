import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/floor_pressure.dart';
import '../data/indoor_positioning_engine.dart';
import '../data/indoor_wifi_fingerprints.dart';

class IndoorPositioningScreen extends StatefulWidget {
  const IndoorPositioningScreen({super.key});

  @override
  State<IndoorPositioningScreen> createState() =>
      _IndoorPositioningScreenState();
}

class _IndoorPositioningScreenState extends State<IndoorPositioningScreen> {
  late final IndoorPositioningEngine _engine = IndoorPositioningEngine(
    pressureSource: const SensorsPlusPressureSource(),
  );
  late final Future<void> _loading = _load();
  IndoorLandpoint? _selectedPoint;
  String _confirmedFloor = '1';
  String? _error;

  Future<void> _load() async {
    final raw =
        jsonDecode(
              await rootBundle.loadString('assets/indoor/vec_floors12345.json'),
            )
            as Map<String, dynamic>;
    final objects = raw['objects'] as List<dynamic>;
    final points = objects
        .cast<Map<String, dynamic>>()
        .where((item) => const {'floor_1', 'floor_2'}.contains(item['floorId']))
        .map((item) {
          final position = item['position'] as Map<String, dynamic>;
          final floorId = item['floorId'] as String;
          return IndoorLandpoint(
            id: item['id'] as String,
            floor: floorId.substring(floorId.lastIndexOf('_') + 1),
            type: item['type'] as String,
            x: (position['x'] as num).toDouble(),
            y: (position['y'] as num).toDouble(),
            z: (position['z'] as num).toDouble(),
          );
        })
        .toList(growable: false);
    await _engine.initialize(points);
    if (points.isNotEmpty) _selectedPoint = points.first;
    _engine.startPressure();
  }

  Future<void> _capture() async {
    final point = _selectedPoint;
    if (point == null) return;
    if (!await _ensureWifiPermission()) return;
    try {
      await _engine.captureFingerprint(point);
      _show('Fingerprint saved at ${point.id}.');
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _locate() async {
    if (!await _ensureWifiPermission()) return;
    try {
      await _engine.scanAndLocate();
      if (_engine.lastWifiMatch == null) {
        setState(
          () => _error =
              'Not enough shared access points. Survey more spots and try again.',
        );
      } else {
        setState(() => _error = null);
      }
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<bool> _ensureWifiPermission() async {
    final permission = await Permission.locationWhenInUse.request();
    if (permission.isGranted) return true;
    if (mounted) {
      _show(
        permission.isPermanentlyDenied
            ? 'Allow location access in Settings to survey nearby Wi-Fi.'
            : 'Location permission is required for Android Wi-Fi scans.',
      );
    }
    return false;
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VEC indoor positioning')),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load VEC points: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListenableBuilder(
          listenable: _engine,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Android Wi-Fi survey',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _engine.canScanWifi
                    ? 'Stand still at each landmark, choose its Unity point, and capture several scans. Fingerprints are saved locally on this phone.'
                    : 'iOS does not expose nearby Wi-Fi scans to this app. Use Android for fingerprint surveys; iPhone can use pressure calibration and AR confirmation.',
              ),
              if (_engine.canScanWifi) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<IndoorLandpoint>(
                  initialValue: _selectedPoint,
                  decoration: const InputDecoration(
                    labelText: 'Unity landpoint',
                  ),
                  items: [
                    for (final point in _engine.points)
                      DropdownMenuItem(
                        value: point,
                        child: Text(
                          'Floor ${point.floor} · ${point.id} (${point.type})',
                        ),
                      ),
                  ],
                  onChanged: _engine.busy
                      ? null
                      : (value) => setState(() => _selectedPoint = value),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _engine.busy ? null : _capture,
                  icon: const Icon(Icons.wifi_find),
                  label: Text(
                    'Capture Wi-Fi fingerprint (${_engine.wifiStore.fingerprints.length} saved)',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _engine.busy || _engine.wifiStore.fingerprints.isEmpty
                      ? null
                      : _locate,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Scan and estimate location'),
                ),
              ],
              const Divider(height: 30),
              const Text(
                'Floor belief',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<String>(
                initialValue: _confirmedFloor,
                decoration: const InputDecoration(
                  labelText: 'Confirm the floor you are currently on',
                ),
                items: [
                  for (final floor in ['1', '2', '3', '4', '5'])
                    DropdownMenuItem(value: floor, child: Text('Floor $floor')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _confirmedFloor = value);
                },
              ),
              OutlinedButton.icon(
                onPressed: () => _engine.confirmStartingFloor(_confirmedFloor),
                icon: const Icon(Icons.layers_outlined),
                label: const Text('Set starting floor / reset belief'),
              ),
              _beliefCard(),
              Text(
                _engine.pressureProfile?.isUsable == true
                    ? 'Pressure profile loaded from saved, user-confirmed floor runs.'
                    : 'Pressure profile needs a recording that starts on floor 1 and has samples from at least one other confirmed floor. Enter floor numbers 1–5 consistently in /dev/floor-pressure.',
              ),
              if (_engine.latestPressure != null)
                Text(
                  'Live pressure: ${_engine.latestPressure!.hPa.toStringAsFixed(2)} hPa',
                ),
              if (_engine.lastWifiMatch case final match?)
                Text(
                  'Wi-Fi match: ${match.pointId}, floor ${match.floor} · ${(match.confidence * 100).round()}% match confidence',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_engine.busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (defaultTargetPlatform == TargetPlatform.android)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Android needs location permission and Location services enabled for Wi-Fi scan results. Scan freshness is limited by Android and the access point environment.',
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _beliefCard() {
    final belief = _engine.floorBelief;
    final point = _engine.likelyPoint;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_searching),
        title: Text(
          belief == null
              ? 'No saved floor belief yet'
              : 'Estimated floor ${belief.floor} · ${(belief.confidence * 100).round()}%',
        ),
        subtitle: Text(
          point == null
              ? 'The estimate persists locally when available.'
              : 'Likely landpoint: ${point.id} (${point.type})',
        ),
      ),
    );
  }
}
