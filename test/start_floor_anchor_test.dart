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
      wallClock: () => _wall.add(now),
    );
    addTearDown(anchor.dispose);
  }

  final source = _FakeSource();
  late final StartFloorAnchor anchor;
  var now = Duration.zero;
  var _noise = 0;

  /// Holds [hPa] for [seconds], with +-0.01 hPa of alternating noise.
  Future<void> hold(
    double hPa,
    int seconds, {
    Duration age = Duration.zero,
  }) async {
    for (var i = 0; i < seconds; i++) {
      now += const Duration(seconds: 1);
      _noise++;
      source.controller.add(
        PressureReading(
          hPa: hPa + (_noise.isEven ? 0.01 : -0.01),
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

  test('blank floor is refused and reads nothing', () async {
    final rig = _Rig();
    expect(rig.anchor.confirmFloor('  '), isFalse);
    expect(rig.source.controller.hasListener, isFalse);
  });

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
    expect(rig.anchor.evidence()!.settled, isFalse);
    expect(rig.anchor.resolved, isFalse);
    await rig.hold(1000, 5);
    expect(rig.anchor.evidence()!.settled, isTrue);
    expect(rig.anchor.resolved, isTrue);
  });

  test('a 0.47 hPa step stops sampling and stays moved', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.47, 40);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.moved, isTrue);
    expect(rig.source.controller.hasListener, isFalse);
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

  for (final resumePressure in [1000.0, 1000.5]) {
    test('a flat window at $resumePressure hPa cannot repair a gap', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      expect(rig.anchor.evidence()!.settled, isTrue);
      rig.gap(10);
      await rig.hold(resumePressure, 40);
      final e = rig.anchor.evidence()!;
      expect(e.settled, isFalse);
      expect(e.moved, resumePressure != 1000);
      expect(rig.source.controller.hasListener, isFalse);
    });
  }

  test('hold range 0.2 never anchors, and the deadline resolves it', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    for (var i = 0; i < 31; i++) {
      await rig.hold(1000 + (i.isEven ? 0.1 : -0.1), 1);
    }
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.moved, isFalse);
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
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.moved, isFalse);
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
    expect(rig.anchor.evidence()!.settled, isFalse);
  });

  for (final delta in [-0.5, 0.5]) {
    test('brief excursion of $delta hPa stays latched', () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 20);
      await rig.hold(1000 + delta, 2);
      await rig.hold(1000, 22);
      expect(rig.anchor.evidence()!.settled, isFalse);
      expect(rig.anchor.evidence()!.moved, isTrue);
    });
  }

  test('first capture at second two leaves the answer uncovered', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    rig.gap(1);
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence()!.settled, isFalse);
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
    expect(rig.anchor.evidence()!.settled, isFalse);
    await rig.hold(1000, 2, age: const Duration(seconds: 2));
    expect(rig.anchor.evidence()!.settled, isTrue);
    rig.gap(2);
    await rig.hold(1000, 1, age: const Duration(milliseconds: 2900));
    expect(rig.anchor.evidence()!.sampleAgeS, 2.9);
  });

  test('redelivery does not increase the number of captured samples', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 1);
    for (var i = 0; i < 6; i++) {
      rig.gap(2);
      await rig.hold(1000, 1);
    }
    await rig.hold(1000, 1, age: const Duration(seconds: 1));
    await rig.hold(1000, 1, age: const Duration(seconds: 2));
    expect(rig.anchor.evidence()!.settled, isFalse);
    expect(rig.anchor.evidence()!.sampleAgeS, 2);
  });

  test('moved stays latched after returning to the anchor level', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.5, 25);
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence()!.moved, isTrue);
  });

  test('freshness is judged at each use, never cached', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence()!.settled, isTrue);
    rig.gap(11); // sensor went quiet after the answer
    final stale = rig.anchor.evidence()!;
    expect(stale.settled, isFalse);
    expect(stale.sampleAgeS, 11);
    expect(stale.ageS, 36);
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
