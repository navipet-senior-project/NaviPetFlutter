import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/floor_pressure.dart';

/// Debug-only screen for Wave D: record relative barometer pressure while the
/// tester confirms which floor they are actually on.
class FloorPressureScreen extends StatefulWidget {
  const FloorPressureScreen({super.key, this.recorder});

  /// Tests inject a fake-backed recorder; production builds its own.
  final FloorPressureRecorder? recorder;

  @override
  State<FloorPressureScreen> createState() => _FloorPressureScreenState();
}

class _FloorPressureScreenState extends State<FloorPressureScreen> {
  final _floor = TextEditingController();
  static final _sharedRecorder = FloorPressureRecorder(
    source: const SensorsPlusPressureSource(),
    store: FloorPressureStore(),
    platform: Platform.operatingSystem,
  );
  late final FloorPressureRecorder recorder =
      widget.recorder ?? _sharedRecorder;

  @override
  void initState() {
    super.initState();
    recorder.stop();
  }

  @override
  void dispose() {
    recorder.stop();
    _floor.dispose();
    super.dispose();
  }

  static String _failureText(PressureFailure? failure) => switch (failure) {
    PressureFailure.sensorMissing => 'This device has no barometer.',
    PressureFailure.denied =>
      'Motion access is denied. Enable Motion & Fitness for NaviPet in Settings.',
    _ => 'The barometer reported an error.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Floor pressure')),
      body: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) {
          final recording = recorder.status == RecorderStatus.recording;
          final delta = recorder.latestDeltaHpa;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _floor,
                      decoration: const InputDecoration(
                        labelText: 'Floor you are standing on',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => recorder.confirmFloor(_floor.text),
                    child: const Text('Confirm floor'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    recorder.busy || (!recording && recorder.persistenceFailed)
                    ? null
                    : recording
                    ? recorder.stop
                    : recorder.start,
                child: Text(recording ? 'Stop' : 'Start recording'),
              ),
              if (recording)
                TextButton(
                  onPressed: recorder.confirmedFloor == null
                      ? null
                      : recorder.beginTransition,
                  child: const Text('Start moving between floors'),
                ),
              const SizedBox(height: 16),
              Text('Confirmed floor: ${recorder.confirmedFloor ?? 'none'}'),
              Text('Samples: ${recorder.sampleCount}'),
              if (delta != null)
                Text('Change: ${delta.toStringAsFixed(2)} hPa'),
              if (recorder.status == RecorderStatus.failed)
                Text(_failureText(recorder.failure)),
              if (recorder.persistenceFailed) ...[
                const Text('Could not save measurements. Try again.'),
                TextButton(
                  onPressed: recorder.busy ? null : recorder.retryPersistence,
                  child: const Text('Retry save'),
                ),
              ],
              const SizedBox(height: 16),
              Text('Saved runs: ${recorder.runs.length}'),
              Row(
                children: [
                  TextButton(
                    onPressed: recorder.runs.isEmpty
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: recorder.exportJson()),
                          ),
                    child: const Text('Copy JSON'),
                  ),
                  TextButton(
                    onPressed:
                        recorder.runs.isEmpty ||
                            recorder.busy ||
                            recorder.persistenceFailed
                        ? null
                        : recorder.clearRuns,
                    child: const Text('Clear runs'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
