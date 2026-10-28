import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:navipet/data/indoor_ar_contract.dart';

import 'support/indoor_ar_fixtures.dart';

void main() {
  group('IndoorArRequest', () {
    test('encodes bridge contract v1', () {
      expect(jsonDecode(jsonEncode(vec119Request().toJson())), {
        'schemaVersion': 1,
        'room': '119',
        'doorKey': 'VEC119',
        'floor': '1',
        'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
        'headingDeg': 185.36,
        'mapCode': 'MSET_XTBY7AM7ZK77',
        'frame': 'multiset-mapset',
      });
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

  group('IndoorArRequest.fromDoorPose', () {
    Map<String, dynamic> pose({Object? headingDeg = 185.36}) => {
      'mapCode': 'MSET_XTBY7AM7ZK77',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC119',
      'floor': '1',
      'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
      'headingDeg': headingDeg,
    };

    test('builds the v1 request from the backend door pose', () {
      final request = IndoorArRequest.fromDoorPose(pose(), room: '119')!;
      expect(request.toJson(), vec119Request().toJson());
    });

    test('accepts integer coordinates', () {
      final json = pose(headingDeg: 5)..['position'] = {'x': 1, 'y': 2, 'z': 3};
      final request = IndoorArRequest.fromDoorPose(json, room: '1')!;
      expect(request.position.x, 1.0);
      expect(request.headingDeg, 5.0);
    });

    test('returns null for a missing or invalid pose', () {
      expect(IndoorArRequest.fromDoorPose(null, room: '119'), isNull);
      expect(
        IndoorArRequest.fromDoorPose(pose(headingDeg: 360), room: '119'),
        isNull,
      );
      expect(
        IndoorArRequest.fromDoorPose(pose(headingDeg: 'x'), room: '119'),
        isNull,
      );
      expect(
        IndoorArRequest.fromDoorPose(pose()..remove('position'), room: '119'),
        isNull,
      );
      expect(
        IndoorArRequest.fromDoorPose(pose()..['doorKey'] = '', room: '119'),
        isNull,
      );
    });
  });
}
