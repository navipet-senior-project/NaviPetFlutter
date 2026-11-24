import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:navipet/data/indoor_ar_contract.dart';

import 'support/indoor_ar_fixtures.dart';

void main() {
  group('IndoorArRequest', () {
    test('encodes bridge contract v2', () {
      expect(jsonDecode(jsonEncode(vec119Request().toJson())), {
        'schemaVersion': 2,
        'room': '119',
        'doorKey': 'VEC119',
        'floor': '1',
        'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
        'headingDeg': 185.36,
        'mapCode': 'MSET_XTBY7AM7ZK77',
        'frame': 'multiset-mapset',
        'capabilities': ['signArrival'],
        'arToken': {
          'token': 'test-token',
          'expiresOn': '2026-01-01T00:30:00.000Z',
        },
      });
    });

    test('localize omits the door pose', () {
      final request = IndoorArRequest.localize(
        room: '119',
        mapCode: IndoorArRequest.buildMapCode,
        frame: IndoorArRequest.buildFrame,
      );
      final json = request.toJson();
      expect(json['mode'], 'localize');
      expect(json.containsKey('position'), isFalse);
      expect(json.containsKey('doorKey'), isFalse);
      expect(json.containsKey('headingDeg'), isFalse);
      expect(json.containsKey('floor'), isFalse);
      expect(json.containsKey('capabilities'), isFalse);
    });

    test('omits arToken when none was minted', () {
      final bare = IndoorArRequest(
        room: '119',
        doorKey: 'VEC119',
        floor: '1',
        position: const IndoorArVector3(0, 0, 0),
        headingDeg: 0,
        mapCode: 'M',
        frame: 'multiset-mapset',
      );
      expect(bare.toJson().containsKey('arToken'), isFalse);
    });

    test('start floor adds all versioned fields to both request modes', () {
      final start = IndoorArStartFloor(
        floor: ' 2 ',
        ageS: 12.5,
        settled: true,
        moved: false,
        sampleAgeS: 0.5,
      );
      final expected = {
        'floorEvidenceVersion': 1,
        'startFloor': '2',
        'startFloorAgeS': 12.5,
        'pressureSinceStart': {
          'settled': true,
          'moved': false,
          'sampleAgeS': 0.5,
        },
      };
      final door = vec119Request().withArToken(testArToken, startFloor: start);
      expect(door.toJson(), containsPair('floor', '1'));
      expect(door.toJson(), containsPair('startFloor', '2'));
      expect(door.toJson(), containsPair('arToken', testArToken.toJson()));
      expect(
        jsonDecode(jsonEncode(door.toJson()))['pressureSinceStart'],
        expected['pressureSinceStart'],
      );
      final localize = IndoorArRequest.localize(
        mapCode: IndoorArRequest.buildMapCode,
        frame: IndoorArRequest.buildFrame,
      ).withArToken(testArToken, startFloor: start);
      expect(localize.toJson(), containsPair('startFloorAgeS', 12.5));
      expect(localize.toJson(), contains('arToken'));
      expect(vec119Request().toJson().containsKey('startFloor'), isFalse);
      for (final request in [door, localize]) {
        final wire = jsonDecode(jsonEncode(request.toJson())) as Map;
        for (final field in expected.entries) {
          expect(wire[field.key], field.value);
        }
        final withoutFloor = request
            .withArToken(testArToken, startFloor: null)
            .toJson();
        expect(withoutFloor, containsPair('arToken', testArToken.toJson()));
        expect(withoutFloor.keys, isNot(contains('floorEvidenceVersion')));
        expect(withoutFloor.keys, isNot(contains('startFloor')));
        expect(withoutFloor.keys, isNot(contains('startFloorAgeS')));
        expect(withoutFloor.keys, isNot(contains('pressureSinceStart')));
        expect(
          withoutFloor,
          Map.of(request.toJson())
            ..removeWhere((key, _) => expected.containsKey(key)),
        );
      }
    });

    test('both modes omit unsettled and stale evidence at unrounded ages', () {
      for (final (age, sampleAge, settled, eligible) in [
        (0.0, 0.0, true, true),
        (0.0, 0.0, false, false),
        (1200.0, 10.0, true, true),
        (1200.000001, 10.0, true, false),
        (1201.0, 10.0, true, false),
        (1200.0, 10.0000001, true, false),
        (1200.0, 11.0, true, false),
      ]) {
        final start = IndoorArStartFloor(
          floor: '2',
          ageS: age,
          settled: settled,
          moved: true,
          sampleAgeS: sampleAge,
        );
        for (final request in [
          vec119Request(),
          IndoorArRequest.localize(
            mapCode: IndoorArRequest.buildMapCode,
            frame: IndoorArRequest.buildFrame,
          ),
        ]) {
          final wire =
              jsonDecode(
                    jsonEncode(
                      request
                          .withArToken(testArToken, startFloor: start)
                          .toJson(),
                    ),
                  )
                  as Map;
          if (eligible) {
            expect(wire['floorEvidenceVersion'], 1);
            expect(wire['startFloorAgeS'], age);
            expect(
              (wire['pressureSinceStart'] as Map)['sampleAgeS'],
              sampleAge,
            );
          } else {
            expect(
              wire,
              request.withArToken(testArToken, startFloor: null).toJson(),
            );
          }
        }
      }
    });

    test('both modes omit all evidence for invalid start floors', () {
      for (final floor in [
        '',
        '  ',
        'Ground',
        '0',
        '-1',
        '+1',
        '1.5',
        '2147483648',
      ]) {
        final start = IndoorArStartFloor(
          floor: floor,
          ageS: 20,
          settled: true,
          moved: false,
          sampleAgeS: 0,
        );
        for (final request in [
          vec119Request(),
          IndoorArRequest.localize(
            mapCode: IndoorArRequest.buildMapCode,
            frame: IndoorArRequest.buildFrame,
          ),
        ]) {
          expect(
            request.withArToken(testArToken, startFloor: start).toJson(),
            request.withArToken(testArToken, startFloor: null).toJson(),
            reason: floor,
          );
        }
      }
    });

    test('start floor rejects bad ages', () {
      IndoorArStartFloor build({double ageS = 0, double sampleAgeS = 0}) =>
          IndoorArStartFloor(
            floor: '1',
            ageS: ageS,
            settled: true,
            moved: false,
            sampleAgeS: sampleAgeS,
          );
      expect(() => build(ageS: -1), throwsArgumentError);
      expect(() => build(ageS: double.nan), throwsArgumentError);
      expect(() => build(sampleAgeS: double.infinity), throwsArgumentError);
    });

    test('a token never shows in toString', () {
      expect(testArToken.toString(), isNot(contains('test-token')));
    });

    test('rejects a heading outside [0, 360)', () {
      expect(() => vec119Request(headingDeg: 360), throwsArgumentError);
      expect(() => vec119Request(headingDeg: -0.1), throwsArgumentError);
      expect(() => vec119Request(headingDeg: double.nan), throwsArgumentError);
    });

    test('rejects an empty floor or map code', () {
      IndoorArRequest build({String floor = '1', String mapCode = 'M'}) =>
          IndoorArRequest(
            room: '119',
            doorKey: 'VEC119',
            floor: floor,
            position: const IndoorArVector3(0, 0, 0),
            headingDeg: 0,
            mapCode: mapCode,
            frame: 'multiset-mapset',
          );
      expect(() => build(floor: ''), throwsArgumentError);
      expect(() => build(mapCode: ''), throwsArgumentError);
    });

    test('rejects a non-finite position', () {
      for (final bad in [double.nan, double.infinity]) {
        expect(
          () => IndoorArRequest(
            room: '119',
            doorKey: 'VEC119',
            floor: '1',
            position: IndoorArVector3(0, bad, 0),
            headingDeg: 0,
            mapCode: 'M',
            frame: 'multiset-mapset',
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects an empty door key', () {
      expect(
        () => IndoorArRequest(
          room: '119',
          doorKey: '',
          floor: '1',
          position: const IndoorArVector3(0, 0, 0),
          headingDeg: 0,
          mapCode: 'MSET_XTBY7AM7ZK77',
          frame: 'multiset-mapset',
        ),
        throwsArgumentError,
      );
    });
  });

  group('IndoorArResult.decode', () {
    void expectBadResult(String raw) {
      final result = IndoorArResult.decode(raw);
      expect(result.status, IndoorArStatus.error, reason: raw);
      expect(result.errorCode, 'BAD_RESULT', reason: raw);
    }

    test('decodes arrived with every field', () {
      final result = IndoorArResult.decode(
        '{"status":"arrived","checkDistanceM":0.42,"confidence":0.9,'
        '"localizedMapCode":"MAP_YXEW0CKO9CX8","localizationQueries":2,'
        '"durationMs":61000}',
      );

      expect(result.status, IndoorArStatus.arrived);
      expect(result.checkDistanceM, 0.42);
      expect(result.confidence, 0.9);
      expect(result.localizedMapCode, 'MAP_YXEW0CKO9CX8');
      expect(result.localizationQueries, 2);
      expect(result.durationMs, 61000);
      expect(result.errorCode, isNull);
    });

    test('accepts an integer distance', () {
      final result = IndoorArResult.decode(
        '{"status":"arrived","checkDistanceM":1,"localizationQueries":0,'
        '"durationMs":10}',
      );
      expect(result.checkDistanceM, 1.0);
    });

    test('decodes the statuses without extra fields', () {
      for (final status in ['cancelled', 'localizationFailed', 'unavailable']) {
        final result = IndoorArResult.decode(
          '{"status":"$status","localizationQueries":1,"durationMs":5}',
        );
        expect(result.status.name, status);
        expect(result.checkDistanceM, isNull);
      }
    });

    test('decodes the results the Android host builds itself', () {
      final unavailable = IndoorArResult.decode(
        '{"status":"unavailable","localizationQueries":0,"durationMs":0}',
      );
      expect(unavailable.status, IndoorArStatus.unavailable);

      final exited = IndoorArResult.decode(
        '{"status":"error","errorCode":"UNITY_EXITED",'
        '"localizationQueries":0,"durationMs":1500}',
      );
      expect(exited.status, IndoorArStatus.error);
      expect(exited.errorCode, 'UNITY_EXITED');
      expect(exited.durationMs, 1500);
    });

    test('sign-confirmed arrival needs no distance', () {
      final result = IndoorArResult.decode(
        '{"status":"arrived","signRoom":"VEC119","localizationQueries":1,'
        '"durationMs":10}',
      );
      expect(result.status, IndoorArStatus.arrived);
      expect(result.checkDistanceM, isNull);
      expect(result.signRoom, 'VEC119');
    });

    test('sign-confirmed arrival keeps a tracked distance', () {
      final result = IndoorArResult.decode(
        '{"status":"arrived","checkDistanceM":2.5,"signRoom":"VEC119",'
        '"localizationQueries":1,"durationMs":10}',
      );
      expect(result.checkDistanceM, 2.5);
      expect(result.signRoom, 'VEC119');
    });

    test('drops a sign room on statuses other than arrived', () {
      final result = IndoorArResult.decode(
        '{"status":"cancelled","signRoom":"VEC119","localizationQueries":0,'
        '"durationMs":5}',
      );
      expect(result.signRoom, isNull);
    });

    test('drops a distance on statuses other than arrived', () {
      final result = IndoorArResult.decode(
        '{"status":"cancelled","checkDistanceM":3,"localizationQueries":0,'
        '"durationMs":5}',
      );
      expect(result.checkDistanceM, isNull);
    });

    test('keeps confidence and map code on non-arrived statuses', () {
      final result = IndoorArResult.decode(
        '{"status":"localizationFailed","confidence":0.1,'
        '"localizedMapCode":"MAP_X","localizationQueries":3,"durationMs":5}',
      );
      expect(result.confidence, 0.1);
      expect(result.localizedMapCode, 'MAP_X');
    });

    test('drops an error code on statuses other than error', () {
      final result = IndoorArResult.decode(
        '{"status":"cancelled","errorCode":"NETWORK","localizationQueries":0,'
        '"durationMs":5}',
      );
      expect(result.errorCode, isNull);
    });

    test('maps contract violations to error BAD_RESULT', () {
      expectBadResult('not json');
      expectBadResult('[]');
      expectBadResult(
        '{"status":"teleported","localizationQueries":0,"durationMs":5}',
      );
      expectBadResult('{"status":"cancelled","durationMs":5}');
      expectBadResult(
        '{"status":"cancelled","localizationQueries":0,"durationMs":"5"}',
      );
      expectBadResult(
        '{"status":"cancelled","localizationQueries":-1,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","localizationQueries":0,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","signRoom":"","localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","signRoom":7,"localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","checkDistanceM":-1,"signRoom":"VEC119",'
        '"localizationQueries":0,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","checkDistanceM":null,"localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","checkDistanceM":-0.1,'
        '"localizationQueries":0,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"error","localizationQueries":0,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"cancelled","confidence":"high",'
        '"localizationQueries":0,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"error","errorCode":"","localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult(
        '{"status":"error","errorCode":7,"localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult(
        '{"status":"cancelled","localizedMapCode":7,"localizationQueries":0,'
        '"durationMs":5}',
      );
      expectBadResult('{"status":5,"localizationQueries":0,"durationMs":5}');
      expectBadResult(
        '{"status":"cancelled","localizationQueries":1.5,"durationMs":5}',
      );
      expectBadResult(
        '{"status":"arrived","checkDistanceM":1e999,"localizationQueries":0,'
        '"durationMs":5}',
      );
    });
  });
}
