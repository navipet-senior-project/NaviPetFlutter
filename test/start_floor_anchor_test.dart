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
class _Rig {
  _Rig() {
    anchor = StartFloorAnchor(source: source, clock: () => now)..start();
  }

  final source = _FakeSource();
  late final StartFloorAnchor anchor;
  var now = Duration.zero;
  var _noise = 0;

  /// Holds [hPa] for [seconds], with +-0.01 hPa of alternating noise.
  Future<void> hold(double hPa, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now += const Duration(seconds: 1);
      _noise++;
      source.controller.add(
        PressureReading(
          hPa: hPa + (_noise.isEven ? 0.01 : -0.01),
          timestamp: DateTime.utc(2026),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Time passes with no samples, as in a recorder omission.
  void gap(int seconds) => now += Duration(seconds: seconds);
}

void main() {
  test('nothing confirmed or no samples yields no evidence', () async {
    final rig = _Rig();
    await rig.hold(1000, 30);
    expect(rig.anchor.evidence(), isNull);
    final empty = _Rig()..anchor.confirmFloor('1');
    expect(empty.anchor.evidence(), isNull);
  });

  test('blank floor is refused and keeps nothing', () async {
    final rig = _Rig();
    expect(rig.anchor.confirmFloor('  '), isFalse);
    await rig.hold(1000, 30);
    expect(rig.anchor.evidence(), isNull);
  });

  test(
    'unchanged level with noise for 60 s is settled and not moved',
    () async {
      final rig = _Rig();
      await rig.hold(1000, 25);
      rig.anchor.confirmFloor(' 2 ');
      await rig.hold(1000, 60);
      final e = rig.anchor.evidence()!;
      expect(e.floor, '2');
      expect(e.settled, isTrue);
      expect(e.moved, isFalse);
      expect(e.ageS, 60);
      expect(e.sampleAgeS, 0);
    },
  );

  test('step of 0.47 then 40 s hold is settled and moved', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
    rig.anchor.confirmFloor('1');
    await rig.hold(1000, 25);
    await rig.hold(1000.47, 40);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isTrue);
    expect(e.moved, isTrue);
  });

  test('0.22 posture shift is not a move', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
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
      await rig.hold(1000, 25);
      rig.anchor.confirmFloor('1');
      await rig.hold(1000, 25);
      rig.gap(25);
      await rig.hold(1000.5, 40);
      final e = rig.anchor.evidence()!;
      expect(e.settled, isTrue);
      expect(e.moved, isTrue);
    },
  );

  test('hold range 0.2 is not settled, so no anchor and no move', () async {
    final rig = _Rig();
    rig.anchor.confirmFloor('1');
    for (var i = 0; i < 30; i++) {
      await rig.hold(1000 + (i.isEven ? 0.1 : -0.1), 1);
    }
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.moved, isFalse);
  });

  test('confirming while unsettled never anchors later', () async {
    final rig = _Rig();
    for (var i = 0; i < 10; i++) {
      await rig.hold(1000 + i * 0.2, 1); // still climbing
    }
    rig.anchor.confirmFloor('1');
    await rig.hold(1003, 60); // settles afterwards
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.moved, isFalse);
    // A fresh confirmation once settled anchors.
    rig.anchor.confirmFloor('2');
    expect(rig.anchor.evidence()!.settled, isTrue);
  });

  test('moved stays latched after returning to the anchor level', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
    rig.anchor.confirmFloor('1');
    await rig.hold(1000.5, 25);
    await rig.hold(1000, 25);
    expect(rig.anchor.evidence()!.moved, isTrue);
  });

  test('a stale last sample is not settled and reports its age', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
    rig.anchor.confirmFloor('1');
    rig.gap(15);
    final e = rig.anchor.evidence()!;
    expect(e.settled, isFalse);
    expect(e.sampleAgeS, 15);
  });

  test('confirming again restarts the anchor and age', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
    rig.anchor.confirmFloor('1');
    await rig.hold(1000.5, 25);
    rig.anchor.confirmFloor('2');
    final e = rig.anchor.evidence()!;
    expect(e.floor, '2');
    expect(e.moved, isFalse);
    expect(e.ageS, 0);
  });

  test('a sensor error ends the evidence', () async {
    final rig = _Rig();
    await rig.hold(1000, 25);
    rig.anchor.confirmFloor('1');
    rig.source.controller.addError(
      const PressureUnavailable(PressureFailure.denied),
    );
    await Future<void>.delayed(Duration.zero);
    expect(rig.anchor.evidence(), isNull);
  });
}
