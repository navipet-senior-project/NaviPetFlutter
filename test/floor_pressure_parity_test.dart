import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/floor_pressure.dart';
import 'package:navipet/data/start_floor_anchor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The pressure recorder (raw deltas, kept on the phone) and the floor anchor
/// (privacy-safe summary for Unity) read the same `SensorsPlusPressureSource`.
/// These tests drive that real source through the plugin's own channels, so
/// the units, sampling request and timestamps are the ones both consumers get.
const _method = MethodChannel('dev.fluttercommunity.plus/sensors/method');
const _barometer = EventChannel('dev.fluttercommunity.plus/sensors/barometer');

final _wall = DateTime.utc(2026);

class _Rig {
  _Rig() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_method, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      _barometer,
      MockStreamHandler.inline(onListen: (_, sink) => this.sink = sink),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(_method, null);
      messenger.setMockStreamHandler(_barometer, null);
    });
    anchor = StartFloorAnchor(
      source: const SensorsPlusPressureSource(),
      clock: () => now,
      wallClock: () => _wall.add(now),
    );
    recorder = FloorPressureRecorder(
      source: const SensorsPlusPressureSource(),
      store: FloorPressureStore(),
      platform: 'ios',
    );
    addTearDown(anchor.reset);
    addTearDown(recorder.dispose);
  }

  final calls = <MethodCall>[];
  MockStreamHandlerEventSink? sink;
  late final StartFloorAnchor anchor;
  late final FloorPressureRecorder recorder;
  var now = Duration.zero;
  var _noise = 0;

  /// One plugin event per second: `[hPa, microsecondsSinceEpoch]`.
  Future<void> hold(double hPa, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now += const Duration(seconds: 1);
      _noise++;
      sink!.success(<double>[
        hPa + (_noise.isEven ? 0.01 : -0.01),
        _wall.add(now).microsecondsSinceEpoch.toDouble(),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'the source passes the plugin hPa and capture time through unchanged',
    () async {
      final rig = _Rig();
      final readings = <PressureReading>[];
      final sub = const SensorsPlusPressureSource().readings().listen(
        readings.add,
      );
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      rig.sink!.success(<double>[1013.25, 1234567000.0]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(readings.single.hPa, 1013.25);
      expect(
        readings.single.timestamp,
        DateTime.fromMicrosecondsSinceEpoch(1234567000),
      );
      // The plugin is asked for 1 Hz, the cadence the 0.30 hPa rule was measured at.
      expect(rig.calls.single.method, 'setBarometerSamplingPeriod');
      expect(rig.calls.single.arguments, 1000000);
    },
  );

  test(
    'a stair-sized step reads the same size in the recorder and the anchor',
    () async {
      final rig = _Rig();
      rig.recorder.start();
      rig.recorder.confirmFloor('1');
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      await rig.hold(1000.47, 40);

      // Recorder: raw change against its first reading, in hPa, kept on the phone.
      final recorded = rig.recorder.latestDeltaHpa!;
      expect(recorded, closeTo(0.47, 0.03));

      // Anchor: the same step crosses the same 0.30 hPa line.
      final evidence = rig.anchor.evidence()!;
      expect(evidence.moved, isTrue);
      expect(recorded.abs(), greaterThanOrEqualTo(StartFloorAnchor.moveHpa));
    },
  );

  test('a flat hold stays inside the settled range in both', () async {
    final rig = _Rig();
    rig.recorder.start();
    rig.recorder.confirmFloor('1');
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 60);

    expect(rig.recorder.latestDeltaHpa!.abs(), lessThan(0.03));
    final evidence = rig.anchor.evidence()!;
    expect(evidence.moved, isFalse);
  });

  test(
    'Unity gets no pressure: only flags and ages, never the recorder values',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('2');
      await rig.hold(1013.25, 30);

      final wire = rig.anchor.evidence()!.toJson();
      expect(wire.keys, {
        'floorEvidenceVersion',
        'startFloor',
        'startFloorAgeS',
        'pressureSinceStart',
      });
      expect((wire['pressureSinceStart']! as Map).keys, {
        'settled',
        'moved',
        'sampleAgeS',
      });
      final text = jsonEncode(wire);
      expect(text, isNot(contains('1013')));
      expect(text, isNot(contains('deltaHpa')));
      expect(text, isNot(contains('2026')));
    },
  );

  test(
    'the stair-sized step reaches Unity as a signed delta plus the boot stamp',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('2');
      await rig.hold(1000, 25);
      await rig.hold(999.53, 40); // pressure fell: the phone went up

      final wire = rig.anchor.evidence(requestSentAtBootS: 777.5)!.toJson();
      expect(wire['requestSentAtBootS'], 777.5);
      final pressure = wire['pressureSinceStart']! as Map;
      expect(pressure['moved'], isTrue);
      expect(pressure['deltaHpa'] as double, closeTo(-0.47, 0.03));
      expect((pressure['deltaHpa'] as double).abs() >= 0.30, isTrue);
      // Relative only: no absolute pressure or wall-clock time leaves the phone.
      final text = jsonEncode(wire);
      expect(text, isNot(contains('999.')));
      expect(text, isNot(contains('1000')));
      expect(text, isNot(contains('2026')));
    },
  );
}
