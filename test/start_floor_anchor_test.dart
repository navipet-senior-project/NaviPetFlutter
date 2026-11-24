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
      wallClock: () => _wall,
    );
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
          timestamp: _wall.subtract(age),
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

  test('step of 0.47 then 40 s hold is settled and moved', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.47, 40);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isTrue);
    expect(e.moved, isTrue);
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

  test(
    '25 s of travel without samples then a hold at a new level moved',
    () async {
      final rig = _Rig();
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      rig.gap(25);
      await rig.hold(1000.5, 40);
      final e = rig.anchor.evidence()!;
      expect(e.settled, isTrue);
      expect(e.moved, isTrue);
    },
  );

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

  test('first samples arriving late leave the answer uncovered', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    rig.gap(8); // e.g. a permission dialog delayed the sensor
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence()!.settled, isFalse);
    expect(rig.anchor.resolved, isTrue);
  });

  test('readings the sensor stamped as old are never trusted', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 30, age: const Duration(seconds: 10));
    expect(rig.anchor.evidence(), isNull);
    expect(rig.anchor.resolved, isTrue);
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
