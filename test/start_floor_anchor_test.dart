import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/floor_pressure.dart';
import 'package:navipet/data/start_floor_anchor.dart';

class _FakeSource implements PressureSource {
  final controller = StreamController<PressureReading>.broadcast();

  @override
  Stream<PressureReading> readings() => controller.stream;
}

/// Drives the anchor on a fake monotonic clock; one reading per second.
final _wall = DateTime.utc(2026);

class _Rig {
  _Rig() {
    anchor = StartFloorAnchor(
      source: source,
      clock: () => now,
      wallClock: () => _wall.add(now + wallOffset),
      bootClock: () => bootRead(),
    );
    addTearDown(anchor.reset);
  }

  final source = _FakeSource();
  late final StartFloorAnchor anchor;

  /// Confirms and lets the boot clock read land before time moves, as the
  /// native reply does in the first milliseconds of a real hold.
  Future<void> confirm(String floor) async {
    anchor.confirmFloor(floor);
    await Future<void>.delayed(Duration.zero);
  }

  var now = Duration.zero;
  var wallOffset = Duration.zero;

  /// Time the device spent suspended. The boot clock counts it; the fake
  /// monotonic clock, like Android's, does not.
  var asleep = Duration.zero;
  double get bootS => 5000 + (now + asleep).inMicroseconds / 1e6;
  late Future<double?> Function() bootRead = () async => bootS;
  var _noise = 0;

  /// Holds [hPa] for [seconds], with alternating [noiseHpa].
  Future<void> hold(
    double hPa,
    int seconds, {
    Duration age = Duration.zero,
    double noiseHpa = 0.01,
  }) async {
    for (var i = 0; i < seconds; i++) {
      now += const Duration(seconds: 1);
      _noise++;
      source.controller.add(
        PressureReading(
          hPa: hPa + (_noise.isEven ? noiseHpa : -noiseHpa),
          timestamp: _wall.add(now - age),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Time passes with no samples, as in a recorder omission.
  void gap(int seconds) => now += Duration(seconds: seconds);
}

void main() {
  test('no sensor read until a floor is confirmed', () async {
    final rig = _Rig();
    expect(rig.source.controller.hasListener, isFalse);
    await rig.hold(1000, 30);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isFalse);
    rig.anchor.confirmFloor('1');
    expect(rig.source.controller.hasListener, isTrue);
    expect(rig.anchor.evidence(), isNull, reason: 'earlier samples not kept');
  });

  test(
    'invalid floors do not start capture or replace a confirmation',
    () async {
      final rig = _Rig();
      const invalid = [
        '',
        '  ',
        'Ground',
        '0',
        '-1',
        '+1',
        '1.5',
        '2147483648',
      ];
      for (final floor in invalid) {
        expect(rig.anchor.confirmFloor(floor), isFalse, reason: floor);
        expect(rig.source.controller.hasListener, isFalse);
      }
      rig.anchor.confirmFloor('2');
      await rig.hold(1000, 20);
      for (final floor in invalid) {
        expect(rig.anchor.confirmFloor(floor), isFalse, reason: floor);
      }
      expect(rig.anchor.evidence()?.floor, '2');
      expect(rig.anchor.evidence()?.ageS, 20);
    },
  );

  test(
    'unchanged level with noise for 60 s is settled and not moved',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor(' 2 ');
      await rig.hold(1000, 60);
      final e = rig.anchor.evidence()!;
      expect(e.floor, '2');
      expect(e.moved, isFalse);
      expect(e.ageS, 60);
      expect(e.sampleAgeS, 0);
      expect(rig.anchor.resolved, isTrue);
    },
  );

  test('before a full window has passed there is no anchor yet', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 15);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isFalse);
    await rig.hold(1000, 5);
    expect(rig.anchor.evidence(), isNotNull);
    expect(rig.anchor.resolved, isTrue);
  });

  for (final (firstPressure, expectedMoved) in [
    (1000.04, true),
    (1000.15, null),
  ]) {
    test(
      'initial hold range and trailing median at $firstPressure hPa',
      () async {
        final rig = _Rig();
        rig.anchor.confirmFloor('1');
        rig.now = const Duration(milliseconds: 200);
        rig.source.controller.add(
          PressureReading(hPa: firstPressure, timestamp: _wall.add(rig.now)),
        );
        await Future<void>.delayed(Duration.zero);
        await rig.hold(1000.04, 10, noiseHpa: 0);
        await rig.hold(1000, 9, noiseHpa: 0);
        rig.now += const Duration(milliseconds: 100);
        await rig.hold(1000, 1, noiseHpa: 0);
        await rig.hold(1000.33, 21, noiseHpa: 0);
        expect(rig.anchor.evidence()?.moved, expectedMoved);
      },
    );
  }

  test(
    'a pressure spike 250 ms after an accepted capture is dropped',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 1);
      rig.now += const Duration(milliseconds: 250);
      rig.source.controller.add(
        PressureReading(hPa: 1000.08, timestamp: _wall.add(rig.now)),
      );
      await Future<void>.delayed(Duration.zero);
      await rig.hold(1000, 19);
      expect(rig.anchor.evidence()?.moved, isFalse);
    },
  );

  for (final (label, delay, pressure) in [
    ('redelivery', Duration.zero, 1000.01),
    ('capture 250 ms later', Duration(milliseconds: 250), 1000.08),
    ('capture 250 ms earlier', Duration(milliseconds: -250), 1000.08),
  ]) {
    test('$label preserves the settled window and newest sample age', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20);
      expect(rig.anchor.evidence(), isNotNull);
      rig.now += const Duration(milliseconds: 250);
      rig.source.controller.add(
        PressureReading(
          hPa: pressure,
          timestamp: _wall.add(const Duration(seconds: 20) + delay),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final evidence = rig.anchor.evidence();
      expect(evidence?.sampleAgeS, 0.25);
      expect(evidence?.moved, isFalse);
    });
  }

  test('a redelivery survives a 4 ms forward wall-clock adjustment', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20);
    rig.now += const Duration(milliseconds: 250);
    rig.wallOffset = const Duration(milliseconds: 4);
    rig.source.controller.add(
      PressureReading(
        hPa: 1000.01,
        timestamp: _wall.add(rig.now - const Duration(milliseconds: 250)),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rig.anchor.evidence()?.sampleAgeS, 0.254);
  });

  test(
    'a backward capture clears the window but preserves the anchor',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20);
      expect(rig.anchor.evidence(), isNotNull);
      rig.now += const Duration(milliseconds: 250);
      rig.source.controller.add(
        PressureReading(
          hPa: 1000,
          timestamp: _wall.add(rig.now - const Duration(milliseconds: 750)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(rig.anchor.evidence(), isNull);
      expect(rig.source.controller.hasListener, isTrue);
      await rig.hold(1000, 18);
      expect(rig.anchor.evidence(), isNull);
      await rig.hold(1000, 1);
      expect(rig.anchor.evidence()?.moved, isFalse);
    },
  );

  for (final (gap, pressure, moved) in [
    (3, 1000.0, false),
    (25, 999.53, true),
  ]) {
    test('evidence recovers after a ${gap}s capture gap', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      expect(rig.anchor.evidence()?.moved, isFalse);
      rig.gap(gap - 1);
      await rig.hold(pressure, 40);
      expect(rig.anchor.evidence()?.floor, '1');
      expect(rig.anchor.evidence()?.moved, moved);
      expect(rig.source.controller.hasListener, isTrue);
    });
  }

  test(
    'a long gap keeps movement latched after returning to the anchor',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      await rig.hold(1000.5, 25);
      rig.gap(24);
      await rig.hold(1000, 40);
      expect(rig.anchor.evidence()?.moved, isTrue);
    },
  );

  for (final (label, rawGapMs, skewBeforeMs, skewAfterMs, resets) in [
    ('9.9 s on both clocks', 9900, 0, 0, false),
    ('10 s on both clocks', 10000, 0, 0, true),
    ('10 s on the sensor clock only', 10000, 0, 4, true),
    ('10 s on the elapsed clock only', 9996, 4, 0, true),
  ]) {
    test('capture gap of $label', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 24);
      rig.wallOffset = Duration(milliseconds: skewBeforeMs);
      await rig.hold(1000, 1);
      expect(rig.anchor.evidence(), isNotNull);
      rig.wallOffset = Duration(milliseconds: skewAfterMs);
      rig.now += Duration(milliseconds: rawGapMs);
      rig.source.controller.add(
        PressureReading(hPa: 1000, timestamp: _wall.add(rig.now)),
      );
      await Future<void>.delayed(Duration.zero);
      await rig.hold(1000, 5);
      expect(rig.anchor.evidence(), resets ? isNull : isNotNull);
      expect(rig.source.controller.hasListener, isTrue);
    });
  }

  test('a settled 0.47 hPa step latches movement', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.47, 40);
    final e = rig.anchor.evidence()!;
    expect(e.moved, isTrue);
    expect(rig.source.controller.hasListener, isTrue);
  });

  test('0.22 posture shift is not a move', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.22, 40);
    final e = rig.anchor.evidence()!;
    expect(e.moved, isFalse);
  });

  for (final (low, high, settled) in [
    (1000.01, 1000.069, true),
    (1000.01, 1000.07, false),
    (1000.00, 1000.06, false),
  ]) {
    test('a range from $low to $high hPa at confirmation', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(low, 19, noiseHpa: 0);
      await rig.hold(high, 1, noiseHpa: 0);
      expect(rig.anchor.evidence(), settled ? isNotNull : isNull);
    });
  }

  test('a settled 0.30 hPa step latches movement', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20, noiseHpa: 0);
    await rig.hold(1000.30, 21, noiseHpa: 0);
    await rig.hold(1000, 21, noiseHpa: 0);
    expect(rig.anchor.evidence()?.moved, isTrue);
  });

  for (final level in [999.70, 1000.30]) {
    test(
      'roundoff at $level hPa latches movement but omits the delta',
      () async {
        final rig = _Rig();
        await rig.confirm('1');
        await rig.hold(1000, 20, noiseHpa: 0);
        await rig.hold(level, 21, noiseHpa: 0);
        final evidence = rig.anchor.evidence(requestSentAtBootS: rig.bootS)!;
        expect(evidence.deltaHpa!.abs(), lessThan(0.30));
        expect(evidence.toJson()['pressureSinceStart'], {
          'settled': true,
          'moved': true,
          'sampleAgeS': 0,
        });
      },
    );
  }

  test(
    'a 0.30 hPa step counts when the window settles between readings',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20, noiseHpa: 0);
      await rig.hold(1000.15, 1, noiseHpa: 0);
      await rig.hold(1000.30, 20, noiseHpa: 0);
      expect(rig.anchor.evidence(), isNull);
      rig.now += const Duration(milliseconds: 100);
      expect(rig.anchor.evidence()?.moved, isTrue);
      await rig.hold(1000, 21, noiseHpa: 0);
      expect(rig.anchor.evidence()?.moved, isTrue);
    },
  );

  for (final nextCapture in [42, 45]) {
    test(
      'a settled step latches before the return sample at ${nextCapture}s',
      () async {
        final rig = _Rig();
        rig.anchor.confirmFloor('1');
        await rig.hold(1000, 20, noiseHpa: 0);
        await rig.hold(1000.15, 1, noiseHpa: 0);
        await rig.hold(1000.30, 20, noiseHpa: 0);
        rig.gap(nextCapture - 42);
        await rig.hold(1000, 21, noiseHpa: 0);
        expect(rig.anchor.evidence()?.moved, isTrue);
      },
    );
  }

  test('a backward capture reset preserves settled movement', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20, noiseHpa: 0);
    await rig.hold(1000.15, 1, noiseHpa: 0);
    await rig.hold(1000.30, 20, noiseHpa: 0);
    rig.gap(1);
    rig.source.controller.add(
      PressureReading(
        hPa: 1000,
        timestamp: _wall.add(rig.now - const Duration(milliseconds: 1500)),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rig.anchor.evidence(), isNull);
    await rig.hold(1000, 21, noiseHpa: 0);
    expect(rig.anchor.evidence()?.moved, isTrue);
  });

  test('hold range 0.2 never anchors, and the deadline resolves it', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    for (var i = 0; i < 31; i++) {
      await rig.hold(1000 + (i.isEven ? 0.1 : -0.1), 1);
    }
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isTrue);
    expect(rig.source.controller.hasListener, isFalse);
  });

  test('unsettled at the answer never anchors later', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    for (var i = 0; i < 10; i++) {
      await rig.hold(1000 + i * 0.2, 1); // still climbing
    }
    await rig.hold(1003, 60); // settles, but after the deadline
    expect(rig.anchor.evidence(), isNull);
    // A fresh confirmation once settled anchors.
    rig.anchor.confirmFloor('2');
    await rig.hold(1003, 25);
    expect(rig.anchor.evidence(), isNotNull);
  });

  test('a transition in the first two seconds rules out the answer', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 1);
    await rig.hold(1000.25, 1);
    await rig.hold(1000.5, 20);
    expect(rig.anchor.evidence(), isNull);
  });

  for (final delta in [-0.5, 0.5]) {
    test('brief excursion of $delta hPa does not latch movement', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20);
      await rig.hold(1000 + delta, 2);
      await rig.hold(1000, 22);
      expect(rig.anchor.evidence(), isNotNull);
      expect(rig.anchor.evidence()!.moved, isFalse);
    });
  }

  test('first capture at second two leaves the answer uncovered', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    rig.gap(1);
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isTrue);
    expect(rig.source.controller.hasListener, isFalse);
  });

  test('readings the sensor stamped as old are never trusted', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 30, age: const Duration(seconds: 10));
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isTrue);
  });

  test('future and pre-confirmation captures are rejected', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 1, age: const Duration(seconds: -1));
    expect(rig.anchor.evidence(), isNull);
    await rig.hold(1000, 1, age: const Duration(milliseconds: 2900));
    expect(rig.anchor.evidence(), isNull);
  });

  test('capture time controls when the window and newest sample end', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20, age: const Duration(seconds: 2));
    expect(rig.anchor.evidence(), isNull);
    await rig.hold(1000, 2, age: const Duration(seconds: 2));
    expect(rig.anchor.evidence(), isNotNull);
    rig.gap(1);
    await rig.hold(1000, 1, age: const Duration(milliseconds: 2900));
    expect(rig.anchor.evidence(), isNull);
  });

  test(
    'a backward clock step cannot complete the hold with an old capture',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 19);
      rig.now = const Duration(milliseconds: 20900);
      rig.wallOffset = const Duration(seconds: -1);
      rig.source.controller.add(
        PressureReading(
          hPa: 1000,
          timestamp: _wall.add(const Duration(milliseconds: 19700)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(rig.source.controller.hasListener, isFalse);
      expect(rig.anchor.resolved, isTrue);
      expect(rig.anchor.evidence(), isNull);
    },
  );

  test(
    'a 20 ms rollback rejects a queued capture before the window ends',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 19);
      rig.now = const Duration(milliseconds: 20100);
      rig.wallOffset = const Duration(milliseconds: -20);
      rig.source.controller.add(
        PressureReading(
          hPa: 1000,
          timestamp: _wall.add(const Duration(milliseconds: 19990)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(rig.anchor.evidence(), isNull);
      expect(rig.source.controller.hasListener, isFalse);
    },
  );

  test(
    'a slight rollback cannot advance a capture into the full window',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 19);
      rig.now = const Duration(milliseconds: 20100);
      rig.wallOffset = const Duration(milliseconds: -4);
      rig.source.controller.add(
        PressureReading(
          hPa: 1000,
          timestamp: _wall.add(const Duration(milliseconds: 19998)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(rig.anchor.resolved, isFalse);
      expect(rig.anchor.evidence(), isNull);
    },
  );

  test('a small forward step cannot hide a gap in plugin timestamps', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 19);
    rig.now = const Duration(milliseconds: 21500);
    rig.wallOffset = const Duration(milliseconds: 4);
    rig.source.controller.add(
      PressureReading(
        hPa: 1000,
        timestamp: _wall.add(const Duration(milliseconds: 21002)),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.source.controller.hasListener, isFalse);
  });

  test(
    'a slightly future timestamp cannot make a reading younger than arrival',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20);
      await rig.hold(1000, 1, age: const Duration(milliseconds: -4));
      expect(rig.anchor.evidence()!.sampleAgeS, 0);
      rig.gap(1);
      expect(rig.anchor.evidence()!.sampleAgeS, 1);
    },
  );

  for (final step in [-1, 1]) {
    test(
      'a $step s clock step before handoff invalidates existing evidence',
      () async {
        final rig = _Rig();
        rig.anchor.confirmFloor('1');
        await rig.hold(1000, 20);
        expect(rig.anchor.evidence(), isNotNull);
        rig.wallOffset = Duration(seconds: step);
        expect(rig.anchor.evidence(), isNull);
        expect(rig.source.controller.hasListener, isFalse);
        rig.wallOffset = Duration.zero;
        expect(rig.anchor.evidence(), isNull);
      },
    );
  }

  test('redelivery does not extend the capture window', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 1);
    for (var i = 0; i < 9; i++) {
      rig.gap(1);
      await rig.hold(1000, 1);
    }
    await rig.hold(1000, 1, age: const Duration(seconds: 1));
    await rig.hold(1000, 1, age: const Duration(seconds: 2));
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isFalse);
  });

  test('11 s silence omits evidence until a new window settles', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence(), isNotNull);
    rig.gap(11);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.source.controller.hasListener, isTrue);
    await rig.hold(1000, 18);
    expect(rig.anchor.evidence(), isNull);
    await rig.hold(1000, 1);
    expect(rig.anchor.evidence()?.moved, isFalse);
  });

  test('a 17-second span is unsettled even with both edges covered', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20);
    rig.gap(1);
    await rig.hold(1000, 18);
    rig.now += const Duration(milliseconds: 1900);
    expect(rig.anchor.evidence(), isNull);
  });

  test(
    'continuous samples cannot extend confirmation past 20 minutes',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 1199);
      expect(rig.anchor.evidence(), isNotNull);
      await rig.hold(1000, 1);
      expect(rig.source.controller.hasListener, isFalse);
      expect(rig.anchor.evidence(), isNull);
    },
  );

  test('a closed stream invalidates a settled anchor', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20);
    expect(rig.anchor.evidence(), isNotNull);
    await rig.source.controller.close();
    expect(rig.anchor.evidence(), isNull);
  });

  test('confirming again drops old samples and restarts the anchor', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.5, 25);
    rig.anchor.confirmFloor('2');
    expect(rig.anchor.evidence(), isNull);
    await rig.hold(1000.5, 25);
    final e = rig.anchor.evidence()!;
    expect(e.floor, '2');
    expect(e.moved, isFalse);
    expect(e.ageS, 25);
  });

  test('reset stops reading and forgets the answer', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.anchor.reset();
    expect(rig.source.controller.hasListener, isFalse);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isFalse);
  });

  test('a sensor error ends the evidence and resolves', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 5);
    rig.source.controller.addError(
      const PressureUnavailable(PressureFailure.denied),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isTrue);
  });

  group('deltaHpa and boot stamp', () {
    test(
      'a step down is a negative delta and passes the stamp through',
      () async {
        final rig = _Rig();
        await rig.confirm('1');
        await rig.hold(1000, 25);
        await rig.hold(999.53, 40);
        final stamp = rig.bootS;
        final evidence = rig.anchor.evidence(requestSentAtBootS: stamp)!;
        expect(evidence.deltaHpa, closeTo(-0.47, 0.02));
        expect(evidence.moved, isTrue);
        expect(evidence.requestSentAtBootS, stamp);
        expect(evidence.toJson()['requestSentAtBootS'], stamp);
        expect(
          (evidence.toJson()['pressureSinceStart']! as Map)['deltaHpa'],
          evidence.deltaHpa,
        );
      },
    );

    test('a step up is a positive delta', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('3');
      await rig.hold(1000, 25);
      await rig.hold(1000.82, 40);
      expect(rig.anchor.evidence()!.deltaHpa, closeTo(0.82, 0.02));
    });

    test('no stamp, no stamp or delta on the wire', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      await rig.hold(999.53, 40);
      final wire = rig.anchor.evidence()!.toJson();
      expect(wire, isNot(contains('requestSentAtBootS')));
      expect((wire['pressureSinceStart']! as Map), isNot(contains('deltaHpa')));
    });

    test('returning to the anchor keeps moved but sends no delta', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      await rig.hold(999.53, 25);
      await rig.hold(1000, 40);
      final evidence = rig.anchor.evidence(requestSentAtBootS: 9)!;
      expect(evidence.moved, isTrue);
      final wire = evidence.toJson();
      expect(wire, isNot(contains('requestSentAtBootS')));
      final pressure = wire['pressureSinceStart']! as Map;
      expect(pressure['moved'], isTrue);
      expect(pressure, isNot(contains('deltaHpa')));
    });

    test('an unmoved hold sends no delta', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 40);
      final wire = rig.anchor.evidence(requestSentAtBootS: 9)!.toJson();
      expect((wire['pressureSinceStart']! as Map), isNot(contains('deltaHpa')));
      expect(wire, isNot(contains('requestSentAtBootS')));
    });
  });

  // Android's monotonic clock stops while the device is suspended; the boot
  // clock the stamp comes from does not. Evidence must not span a suspend.
  group('suspend-inclusive boot clock', () {
    Future<_Rig> movedRig() async {
      final rig = _Rig();
      await rig.confirm('1');
      await rig.hold(1000, 25);
      await rig.hold(999.53, 40);
      return rig;
    }

    test('a stamp from the same running clock is kept', () async {
      final rig = await movedRig();
      rig.now += const Duration(milliseconds: 200); // reply latency
      final stamp = rig.bootS - 0.2;
      final evidence = rig.anchor.evidence(requestSentAtBootS: stamp)!;
      expect(evidence.requestSentAtBootS, stamp);
      expect(evidence.toJson()['requestSentAtBootS'], stamp);
    });

    test('a suspend only the boot clock sees omits the evidence', () async {
      final rig = await movedRig();
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNotNull);
      // The wall clock is unreliable here, so only the boot clock shows it.
      rig.asleep = const Duration(minutes: 10);
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNull);
      expect(rig.source.controller.hasListener, isFalse);
      rig.asleep = Duration.zero;
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNull);
    });

    test('a full suspend, wall clock included, omits the evidence', () async {
      final rig = await movedRig();
      rig.asleep = const Duration(seconds: 60);
      rig.wallOffset = const Duration(seconds: 60);
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNull);
      expect(rig.anchor.evidence(), isNull);
      expect(rig.source.controller.hasListener, isFalse);
    });

    test('the old last reading never looks fresh after a suspend', () async {
      final rig = await movedRig();
      rig.asleep = const Duration(seconds: 8);
      // 8 s asleep is inside the 10 s sample bound if only the monotonic age counts.
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNull);
    });

    test('a stamp from another clock is not sent, the rest is kept', () async {
      final rig = await movedRig();
      final evidence = rig.anchor.evidence(requestSentAtBootS: rig.bootS - 60)!;
      expect(evidence.moved, isTrue);
      expect(evidence.requestSentAtBootS, isNull);
      expect(evidence.toJson(), isNot(contains('requestSentAtBootS')));
    });

    test('an unreadable boot clock leaves the wall-clock check', () async {
      final rig = _Rig();
      rig.bootRead = () async => null;
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      await rig.hold(999.53, 40);
      expect(
        rig.anchor.evidence(requestSentAtBootS: 77)!.requestSentAtBootS,
        77,
      );
      rig.wallOffset = const Duration(seconds: 60);
      expect(rig.anchor.evidence(requestSentAtBootS: 77), isNull);
    });

    test('a failing boot clock read does not break confirmation', () async {
      final rig = _Rig();
      rig.bootRead = () async => throw StateError('no host');
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      expect(rig.anchor.evidence(), isNotNull);
    });

    test('a reply that lands after reset or a new floor is ignored', () async {
      final rig = _Rig();
      final late = Completer<double?>();
      rig.bootRead = () => late.future;
      rig.anchor.confirmFloor('1');
      await rig.anchor.reset();
      rig.bootRead = () async => rig.bootS;
      await rig.confirm('2');
      await rig.hold(1000, 25);
      late.complete(1); // would read as a long suspend if it were kept
      await Future<void>.delayed(Duration.zero);
      expect(rig.anchor.evidence(requestSentAtBootS: rig.bootS), isNotNull);
    });
  });
}
