import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navipet/data/floor_pressure.dart';
import 'package:navipet/data/indoor_particle_filter.dart';
import 'package:navipet/data/indoor_positioning_engine.dart';
import 'package:navipet/data/indoor_wifi_fingerprints.dart';
import 'package:navipet/screens/indoor_positioning_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const floorOnePoint = IndoorLandpoint(
    id: 'VEC101',
    floor: '1',
    type: 'door',
    x: 0,
    y: 0,
    z: 0,
  );
  const floorTwoPoint = IndoorLandpoint(
    id: 'VEC201',
    floor: '2',
    type: 'door',
    x: 10,
    y: 4,
    z: 10,
  );
  const points = [floorOnePoint, floorTwoPoint];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('survey lists floors 1–2 and restores a saved floor 3 belief', (
    tester,
  ) async {
    final filter = IndoorParticleFilter();
    await filter.restore(points);
    filter.seedFloor('3');
    await filter.persist();
    const export = 'assets/indoor/vec_floors123.json';
    rootBundle.evict(export);
    const sensorMethods = MethodChannel(
      'dev.fluttercommunity.plus/sensors/method',
    );
    const barometerEvents = MethodChannel(
      'dev.fluttercommunity.plus/sensors/barometer',
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(sensorMethods, (_) async => null);
    messenger.setMockMethodCallHandler(barometerEvents, (_) async => null);

    await tester.pumpWidget(const MaterialApp(home: IndoorPositioningScreen()));
    final landpointPicker = find.byType(DropdownButton<IndoorLandpoint>);
    for (
      var attempt = 0;
      attempt < 50 && !tester.any(landpointPicker);
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final picker = tester.widget<DropdownButton<IndoorLandpoint>>(
      landpointPicker,
    );
    expect(picker.value?.id, 'VECelev2A');
    expect(picker.items!.map((item) => item.value!.floor).toSet(), {'1', '2'});
    await tester.scrollUntilVisible(find.text('Estimated floor 3 · 100%'), 160);
    expect(find.text('Estimated floor 3 · 100%'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('Wi-Fi matcher chooses the closest surveyed landpoint', () {
    final live = WifiScanSnapshot(
      capturedAt: DateTime.utc(2026),
      accessPoints: [
        WifiAccessPointReading(bssid: 'ap-a', rssiDbm: -50, frequencyMhz: 2412),
        WifiAccessPointReading(bssid: 'ap-b', rssiDbm: -61, frequencyMhz: 5180),
        WifiAccessPointReading(bssid: 'ap-c', rssiDbm: -72, frequencyMhz: 2462),
      ],
    );
    final training = [
      WifiFingerprint(point: floorOnePoint, scan: live),
      WifiFingerprint(
        point: floorTwoPoint,
        scan: WifiScanSnapshot(
          capturedAt: DateTime.utc(2026),
          accessPoints: const [
            WifiAccessPointReading(
              bssid: 'ap-a',
              rssiDbm: -70,
              frequencyMhz: 2412,
            ),
            WifiAccessPointReading(
              bssid: 'ap-b',
              rssiDbm: -80,
              frequencyMhz: 5180,
            ),
            WifiAccessPointReading(
              bssid: 'ap-c',
              rssiDbm: -90,
              frequencyMhz: 2462,
            ),
          ],
        ),
      ),
    ];

    final result = const WifiFingerprintMatcher().estimate(live, training);

    expect(result?.pointId, 'VEC101');
    expect(result?.floor, '1');
  });

  test(
    'pressure profile compares readings relative to the confirmed start floor',
    () {
      final profile = VecPressureProfile.fromRuns([
        FloorPressureRun(
          platform: 'android',
          samples: const [
            FloorPressureSample(floor: '1', elapsedMs: 0, deltaHpa: 0),
            FloorPressureSample(floor: '1', elapsedMs: 1000, deltaHpa: .01),
            FloorPressureSample(floor: '2', elapsedMs: 5000, deltaHpa: -.4),
            FloorPressureSample(floor: '2', elapsedMs: 6000, deltaHpa: -.41),
            FloorPressureSample(floor: '3', elapsedMs: 10000, deltaHpa: -.8),
          ],
        ),
      ]);

      final fromFloorOne = profile.infer(-.4, startingFloor: '1');
      final fromFloorTwo = profile.infer(0, startingFloor: '2');

      expect(fromFloorOne?.floor, '2');
      expect(fromFloorOne!.confidence, greaterThan(.8));
      expect(fromFloorTwo?.floor, '2');
    },
  );

  test('particle floor belief persists and restores offline', () async {
    final filter = IndoorParticleFilter(random: math.Random(1));
    await filter.restore(points);
    filter.seedFloor('1');
    filter.observeFloor('2', confidence: .99);
    await filter.persist();

    final restored = IndoorParticleFilter(random: math.Random(2));
    await restored.restore(points);

    expect(restored.floorBelief?.floor, '2');
    expect(restored.floorBelief!.confidence, greaterThan(.9));
  });
}
