import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';

import 'support/indoor_ar_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidIndoorArLauncher.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends the request JSON and decodes the reply', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return '{"status":"cancelled","localizationQueries":0,"durationMs":900}';
    });

    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(received?.method, 'launch');
    expect(
      jsonDecode(received!.arguments as String),
      jsonDecode(jsonEncode(vec119Request().toJson())),
    );
    expect(result.status, IndoorArStatus.cancelled);
    expect(result.durationMs, 900);
  });

  test('returns unavailable when the host has no channel', () async {
    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(result.status, IndoorArStatus.unavailable);
  });

  test('maps a platform exception to error BAD_RESULT', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(result.status, IndoorArStatus.error);
    expect(result.errorCode, 'BAD_RESULT');
  });

  test('maps a null reply to error BAD_RESULT', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(result.errorCode, 'BAD_RESULT');
  });

  test('maps a non-string reply to error BAD_RESULT', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 42);

    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(result.errorCode, 'BAD_RESULT');
  });

  test('maps an unparseable reply to error BAD_RESULT', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'garbage');

    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).launch(vec119Request());

    expect(result.errorCode, 'BAD_RESULT');
  });

  test('defaults to the current platform', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          '{"status":"cancelled","localizationQueries":0,"durationMs":1}',
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      (await AndroidIndoorArLauncher().launch(vec119Request())).status,
      IndoorArStatus.unavailable,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      (await AndroidIndoorArLauncher().launch(vec119Request())).status,
      IndoorArStatus.cancelled,
    );
  });

  test('returns unavailable off Android without calling the host', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });

    final result = await AndroidIndoorArLauncher(
      isAndroid: false,
    ).launch(vec119Request());

    expect(result.status, IndoorArStatus.unavailable);
    expect(called, isFalse);
  });

  test('fake launcher records requests and returns its result', () async {
    final fake = FakeIndoorArLauncher(
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 1,
        durationMs: 10,
      ),
    );

    final result = await fake.launch(vec119Request());

    expect(result.checkDistanceM, 0.5);
    expect(fake.requests.single.doorKey, 'VEC119');
  });

  test('pendingResult decodes a held result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pendingResult');
      return '{"status":"arrived","checkDistanceM":0.8,"localizationQueries":3,"durationMs":41000}';
    });
    final result = await AndroidIndoorArLauncher(
      isAndroid: true,
    ).pendingResult();
    expect(result?.status, IndoorArStatus.arrived);
    expect(result?.checkDistanceM, 0.8);
  });

  test(
    'pendingResult is null when nothing is held or there is no host',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(
        await AndroidIndoorArLauncher(isAndroid: true).pendingResult(),
        isNull,
      );
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await AndroidIndoorArLauncher(isAndroid: true).pendingResult(),
        isNull,
      );
      expect(
        await AndroidIndoorArLauncher(isAndroid: false).pendingResult(),
        isNull,
      );
    },
  );

  test('the fake returns its pending result once', () async {
    final fake = FakeIndoorArLauncher()
      ..pending = const IndoorArResult(
        status: IndoorArStatus.cancelled,
        localizationQueries: 0,
        durationMs: 1,
      );
    expect((await fake.pendingResult())?.status, IndoorArStatus.cancelled);
    expect(await fake.pendingResult(), isNull);
  });
}
