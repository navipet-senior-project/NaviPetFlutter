import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/floor_pressure.dart';
import 'package:navipet/screens/floor_pressure_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSource implements PressureSource {
  final controller = StreamController<PressureReading>.broadcast();

  @override
  Stream<PressureReading> readings() => controller.stream;

  void emit(double hPa, int ms) => controller.add(
    PressureReading(
      hPa: hPa,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000000 + ms),
    ),
  );
}

class _ControlledStore extends FloorPressureStore {
  final loaded = Completer<List<FloorPressureRun>>();
  List<FloorPressureRun> saved = [];
  bool failSave = false;

  @override
  Future<List<FloorPressureRun>> load() => loaded.future;

  @override
  Future<void> save(List<FloorPressureRun> runs) async {
    if (failSave) throw StateError('write failed');
    saved = List.of(runs);
  }
}

class _DelayedClearStore extends FloorPressureStore {
  final clearing = Completer<void>();
  final clearStarted = Completer<void>();
  List<FloorPressureRun> saved = [];

  @override
  Future<List<FloorPressureRun>> load() async => [];

  @override
  Future<void> save(List<FloorPressureRun> runs) async {
    if (runs.isEmpty) {
      clearStarted.complete();
      await clearing.future;
    }
    saved = List.of(runs);
  }
}

class _FailingClearStore extends FloorPressureStore {
  final old = const FloorPressureRun(platform: 'old', samples: []);
  final started = Completer<void>();
  final release = Completer<void>();
  late List<FloorPressureRun> saved = [old];
  bool failClear = true;

  @override
  Future<List<FloorPressureRun>> load() async => List.of(saved);

  @override
  Future<void> save(List<FloorPressureRun> runs) async {
    if (runs.isEmpty && failClear) {
      if (!started.isCompleted) started.complete();
      await release.future;
      throw StateError('clear failed');
    }
    saved = List.of(runs);
  }
}

FloorPressureRecorder _recorder(_FakeSource source) => FloorPressureRecorder(
  source: source,
  store: FloorPressureStore(),
  platform: 'android',
);

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'pressure source keeps the native capture time on $platform',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        const channel = MethodChannel('navipet/floor_pressure');
        const codec = StandardMethodCodec();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        });
        final readings = <PressureReading>[];
        final subscription = const SensorsPlusPressureSource()
            .readings()
            .listen(readings.add);
        await _pump();
        const capturedAt = 1767225600123456;
        await messenger.handlePlatformMessage(
          channel.name,
          codec.encodeSuccessEnvelope([1013.25, capturedAt]),
          null,
        );
        await _pump();
        expect(readings.single.hPa, 1013.25);
        expect(readings.single.timestamp.microsecondsSinceEpoch, capturedAt);
        await subscription.cancel();
        expect(calls, ['listen', 'cancel']);
      },
    );
  }

  test(
    'records change vs first reading per confirmed floor, nothing else',
    () async {
      final source = _FakeSource();
      final recorder = _recorder(source)..start();

      source.emit(1013.25, 0); // before any floor is confirmed: dropped
      await _pump();
      expect(recorder.sampleCount, 0);

      expect(recorder.confirmFloor(' 1 '), isTrue);
      source.emit(1013.25, 1000);
      await _pump();
      recorder.beginTransition();
      source.emit(1013.0, 1500);
      await _pump();
      expect(recorder.confirmFloor('2'), isTrue);
      source.emit(1012.85, 2000);
      await _pump();
      await recorder.stop();

      final samples = recorder.runs.single.samples;
      expect(samples.map((s) => s.floor), ['1', '2']);
      expect(samples.map((s) => s.elapsedMs), [1000, 2000]);
      expect(samples.map((s) => s.deltaHpa), [0.0, -0.4]);
      expect(recorder.runs.single.toJson().toString(), isNot(contains('1013')));
      expect(recorder.status, RecorderStatus.idle);
    },
  );

  test('blank floor is rejected and keeps the previous one', () {
    final recorder = _recorder(_FakeSource());
    recorder.confirmFloor('3');
    expect(recorder.confirmFloor('  '), isFalse);
    expect(recorder.confirmedFloor, '3');
  });

  test('runs persist across recorders and export as JSON', () async {
    final source = _FakeSource();
    final recorder = _recorder(source)
      ..start()
      ..confirmFloor('1');
    source.emit(1000, 0);
    await _pump();
    await recorder.stop();

    final reloaded = _recorder(_FakeSource());
    await reloaded.loadRuns();
    expect(reloaded.runs.single.samples.single.floor, '1');
    expect(reloaded.exportJson(), contains('"platform":"android"'));
  });

  test('missing sensor is reported as failed, not recorded', () async {
    final source = _FakeSource();
    final recorder = _recorder(source)..start();
    source.controller.addError(
      PlatformException(code: 'NO_SENSOR', message: 'Sensor not found'),
    );
    await _pump();
    expect(recorder.status, RecorderStatus.failed);
    expect(recorder.failure, PressureFailure.sensorMissing);
    expect(recorder.runs, isEmpty);
  });

  test('denied motion access and unknown errors are told apart', () {
    expect(
      classifyPressureError(
        PlatformException(
          code: 'UNAVAILABLE',
          message: 'Motion activity is not authorized',
        ),
      ).failure,
      PressureFailure.denied,
    );
    expect(
      classifyPressureError(
        PlatformException(
          code: 'UNAVAILABLE',
          message: 'Barometer is not available on this device',
        ),
      ).failure,
      PressureFailure.sensorMissing,
    );
    expect(
      classifyPressureError(MissingPluginException()).failure,
      PressureFailure.sensorMissing,
    );
    expect(
      classifyPressureError(StateError('x')).failure,
      PressureFailure.error,
    );
  });

  test('samples taken before a failure are kept', () async {
    final source = _FakeSource();
    final recorder = _recorder(source)
      ..start()
      ..confirmFloor('2');
    source.emit(1000, 0);
    source.controller.addError(PlatformException(code: 'UNAVAILABLE'));
    await _pump();
    await _pump();
    expect(recorder.status, RecorderStatus.failed);
    expect(recorder.runs.single.samples, hasLength(1));
  });

  testWidgets('screen shows the unavailable-sensor message', (tester) async {
    final source = _FakeSource();
    await tester.pumpWidget(
      MaterialApp(home: FloorPressureScreen(recorder: _recorder(source))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recording'));
    source.controller.addError(PlatformException(code: 'NO_SENSOR'));
    await tester.pump();
    await tester.pump();
    expect(find.text('This device has no barometer.'), findsOneWidget);
  });

  testWidgets('screen confirms floor and counts samples', (tester) async {
    final source = _FakeSource();
    final recorder = _recorder(source);
    await tester.pumpWidget(
      MaterialApp(home: FloorPressureScreen(recorder: recorder)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Confirm floor'));
    await tester.pump();
    source.emit(1000, 0);
    await tester.pump();
    expect(find.text('Confirmed floor: 2'), findsOneWidget);
    expect(find.text('Samples: 1'), findsOneWidget);
  });

  test('new runs require a fresh floor confirmation', () async {
    final source = _FakeSource();
    final recorder = _recorder(source)..start();
    recorder.confirmFloor('1');
    source.emit(1000, 0);
    await _pump();
    await recorder.stop();
    recorder.start();
    source.emit(999, 1000);
    await _pump();
    expect(recorder.sampleCount, 0);
    recorder.confirmFloor('2');
    source.emit(998, 2000);
    await _pump();
    await recorder.stop();
    expect(recorder.runs.last.samples.single.floor, '2');
  });

  test('disposing a recording saves buffered samples', () async {
    final source = _FakeSource();
    final recorder = _recorder(source)..start();
    recorder.confirmFloor('1');
    source.emit(1000, 0);
    await _pump();
    recorder.dispose();
    await _pump();
    final reloaded = _recorder(_FakeSource());
    await reloaded.loadRuns();
    expect(reloaded.runs.single.samples.single.floor, '1');
  });

  test('pending load completes before saving a run', () async {
    final source = _FakeSource();
    final store = _ControlledStore();
    final old = FloorPressureRun(platform: 'ios', samples: []);
    final recorder = FloorPressureRecorder(
      source: source,
      store: store,
      platform: 'android',
    )..start();
    recorder.confirmFloor('1');
    source.emit(1000, 0);
    await _pump();
    final stopped = recorder.stop();
    expect(store.saved, isEmpty);
    store.loaded.complete([old]);
    await stopped;
    expect(store.saved, hasLength(2));
    expect(store.saved.first, same(old));
    expect(store.saved.last.samples.single.floor, '1');
  });

  test('failed save retains samples and permits retry', () async {
    final source = _FakeSource();
    final store = _ControlledStore()
      ..loaded.complete([])
      ..failSave = true;
    final recorder = FloorPressureRecorder(
      source: source,
      store: store,
      platform: 'android',
    )..start();
    recorder.confirmFloor('2');
    source.emit(1000, 0);
    await _pump();
    await recorder.stop();
    expect(recorder.saveFailed, isTrue);
    expect(recorder.sampleCount, 1);
    expect(recorder.runs, isEmpty);
    recorder.start();
    expect(recorder.status, RecorderStatus.idle);
    store.failSave = false;
    await recorder.stop();
    expect(recorder.saveFailed, isFalse);
    expect(store.saved.single.samples.single.floor, '2');
    expect(recorder.sampleCount, 0);
  });

  for (final trigger in ['stop', 'sensor error', 'dispose']) {
    test('$trigger during clear cancels and saves the active run', () async {
      final source = _FakeSource();
      final store = _DelayedClearStore();
      final recorder = FloorPressureRecorder(
        source: source,
        store: store,
        platform: 'android',
      )..start();
      recorder.confirmFloor('1');
      source.emit(1000, 0);
      await _pump();
      final clear = recorder.clearRuns();
      await store.clearStarted.future;
      Future<void>? stopped;
      if (trigger == 'stop') {
        stopped = recorder.stop();
      } else if (trigger == 'sensor error') {
        source.controller.addError(PlatformException(code: 'NO_SENSOR'));
        await _pump();
      } else {
        recorder.dispose();
      }
      expect(source.controller.hasListener, isFalse);
      store.clearing.complete();
      await clear;
      if (stopped != null) await stopped;
      await _pump();
      expect(store.saved.single.samples.single.floor, '1');
      if (trigger != 'dispose') {
        expect(recorder.busy, isFalse);
        recorder.start();
        expect(source.controller.hasListener, isTrue);
        await recorder.stop();
      }
    });
  }

  for (final stopDuringClear in [false, true]) {
    test(
      'retry failed clear ${stopDuringClear ? 'after stop' : 'while recording'}',
      () async {
        final source = _FakeSource();
        final store = _FailingClearStore();
        final recorder = FloorPressureRecorder(
          source: source,
          store: store,
          platform: 'android',
        )..start();
        recorder.confirmFloor('1');
        source.emit(1000, 0);
        await _pump();
        final clear = recorder.clearRuns();
        await store.started.future;
        final stopped = stopDuringClear ? recorder.stop() : null;
        store.release.complete();
        await clear;
        if (stopped != null) await stopped;
        expect(recorder.clearFailed, isTrue);
        expect(recorder.persistenceFailed, isTrue);
        store.failClear = false;
        await recorder.retryPersistence();
        expect(recorder.persistenceFailed, isFalse);
        if (stopDuringClear) {
          expect(store.saved.single.samples.single.floor, '1');
        } else {
          expect(recorder.status, RecorderStatus.recording);
          expect(source.controller.hasListener, isTrue);
          expect(store.saved, isEmpty);
          await recorder.stop();
          expect(store.saved.single.samples.single.floor, '1');
        }
      },
    );
  }
}
