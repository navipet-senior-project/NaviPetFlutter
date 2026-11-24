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
    );
    addTearDown(anchor.reset);
  }

  final source = _FakeSource();
  late final StartFloorAnchor anchor;
  var now = Duration.zero;
  var wallOffset = Duration.zero;
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
      expect(e.settled, isTrue);
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
    expect(rig.anchor.evidence()!.settled, isTrue);
    expect(rig.anchor.resolved, isTrue);
  });

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

  for (final ageMs in [250, 500]) {
    test(
      'non-increasing capture at age ${ageMs}ms clears the window',
      () async {
        final rig = _Rig();
        rig.anchor.confirmFloor('1');
        await rig.hold(1000, 20);
        expect(rig.anchor.evidence(), isNotNull);
        rig.now += const Duration(milliseconds: 250);
        rig.source.controller.add(
          PressureReading(
            hPa: 1000,
            timestamp: _wall.add(rig.now - Duration(milliseconds: ageMs)),
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
  }

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

  test('a settled 0.47 hPa step latches movement', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.47, 40);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isTrue);
    expect(e.moved, isTrue);
    expect(rig.source.controller.hasListener, isTrue);
  });

  test('0.22 posture shift is not a move', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.22, 40);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isTrue);
    expect(e.moved, isFalse);
  });

  test('a 0.06 hPa range is settled at confirmation and handoff', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000.01, 19, noiseHpa: 0);
    await rig.hold(1000.07, 1, noiseHpa: 0);
    expect(rig.anchor.evidence()?.settled, isTrue);
  });

  test('a settled 0.30 hPa step latches movement', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20, noiseHpa: 0);
    await rig.hold(1000.30, 21, noiseHpa: 0);
    await rig.hold(1000, 21, noiseHpa: 0);
    expect(rig.anchor.evidence()?.moved, isTrue);
  });

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
    },
  );

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
    expect(rig.anchor.evidence()!.settled, isTrue);
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
      expect(rig.anchor.evidence()!.settled, isTrue);
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
    expect(rig.anchor.evidence()!.settled, isTrue);
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
        expect(rig.anchor.evidence()!.settled, isTrue);
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
    expect(rig.anchor.evidence()!.settled, isTrue);
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
      expect(rig.anchor.evidence()!.settled, isTrue);
      await rig.hold(1000, 1);
      expect(rig.source.controller.hasListener, isFalse);
      expect(rig.anchor.evidence(), isNull);
    },
  );

  test('a closed stream invalidates a settled anchor', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 20);
    expect(rig.anchor.evidence()!.settled, isTrue);
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
    expect(e.settled, isTrue);
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
}
