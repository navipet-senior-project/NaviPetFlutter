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
    });
  });
}
