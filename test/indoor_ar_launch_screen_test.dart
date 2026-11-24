import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/campus_search_gateway.dart';
import 'package:navipet/data/floor_pressure.dart';
import 'package:navipet/data/start_floor_anchor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/data/indoor_ar_token_gateway.dart';
import 'package:navipet/screens/indoor_ar_launch_screen.dart';

import 'support/indoor_ar_fixtures.dart';

import 'package:permission_handler/permission_handler.dart';

const _rationale =
    'Allow camera access so NaviPet can point toward this room. '
    'This is a direction to the room, not turn-by-turn guidance.';
const _scanRationale =
    'Allow camera access to scan and find your position. '
    'No door position is saved, so this does not start a route.';
const _cameraOff =
    'Camera access is off. Turn it on in Settings to use AR directions.';

const _cancelled = IndoorArResult(
  status: IndoorArStatus.cancelled,
  localizationQueries: 0,
  durationMs: 1,
);

IndoorArResult _error(String code) => IndoorArResult(
  status: IndoorArStatus.error,
  errorCode: code,
  localizationQueries: 0,
  durationMs: 1,
);

class _ThrowingLauncher implements IndoorArLauncher {
  @override
  Future<IndoorArResult> launch(IndoorArRequest request) =>
      Future.error(StateError('launch failed'));
}

class _PendingLauncher extends FakeIndoorArLauncher {
  final resultReady = Completer<IndoorArResult>();

  @override
  Future<IndoorArResult> launch(IndoorArRequest request) {
    requests.add(request);
    return resultReady.future;
  }
}

class _StreamSource implements PressureSource {
  const _StreamSource(this.stream);

  final Stream<PressureReading> stream;

  @override
  Stream<PressureReading> readings() => stream;
}

class _Session implements AuthTokenProvider {
  var refreshes = 0;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    if (forceRefresh) refreshes++;
    return forceRefresh ? 'session-2' : 'session-1';
  }
}

final _mintedBody = jsonEncode({
  'token': 'test-token',
  'expiresOn': '2026-01-01T00:30:00.000Z',
});

/// The map stands in as a page with an AR tap target, so each tap opens the
/// screen fresh, as it does in the app.
class _Harness {
  _Harness({
    IndoorArResult result = _cancelled,
    this.status = PermissionStatus.denied,
    this.camera = PermissionStatus.granted,
    IndoorArLauncher? launcher,
    IndoorArRequest? request,
    this.anchor,
    String? destinationId = _destinationId,
    Future<http.Response> Function(http.Request)? fetch,
    Future<http.Response> Function(http.Request)? mint,
    DateTime Function()? tokenClock,
    Duration Function()? tokenElapsed,
    Future<PermissionStatus>? pendingStatus,
    Future<PermissionStatus>? pendingPermission,
    Future<double?> Function()? bootClock,
  }) : fake = FakeIndoorArLauncher(result: result) {
    final activeLauncher = launcher ?? fake;
    router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(
                Uri(
                  path: '/ar',
                  queryParameters: {'destination': ?destinationId},
                ).toString(),
              ),
              child: const Text('map'),
            ),
          ),
        ),
        GoRoute(
          path: '/ar',
          builder: (context, state) => IndoorArLaunchScreen(
            launcher: activeLauncher,
            request: request,
            anchor: anchor,
            destinationId: state.uri.queryParameters['destination'],
            gateway: HttpCampusSearchGateway(
              baseUrl: 'https://example.test',
              auth: session,
              client: MockClient((request) async {
                fetchedIds.add(request.url.pathSegments.last);
                return fetch != null
                    ? await fetch(request)
                    : http.Response(_fixture, 200);
              }),
            ),
            tokenGateway: HttpIndoorArTokenGateway(
              baseUrl: 'https://example.test',
              auth: session,
              client: MockClient((request) async {
                mintRequests.add(request);
                return mint != null
                    ? await mint(request)
                    : http.Response(_mintedBody, 200);
              }),
            ),
            now: tokenClock ?? () => DateTime.utc(2026, 1, 1),
            monotonicNow: tokenElapsed,
            bootClock: bootClock,
            cameraStatus: () async {
              statusChecks++;
              return pendingStatus == null ? status : await pendingStatus;
            },
            requestCamera: () async {
              cameraRequests++;
              return pendingPermission == null
                  ? camera
                  : await pendingPermission;
            },
            openSettings: () async {
              settingsOpened++;
              return true;
            },
          ),
        ),
      ],
    );
  }

  final fetchedIds = <String>[];
  final mintRequests = <http.Request>[];
  final session = _Session();
  final FakeIndoorArLauncher fake;
  final StartFloorAnchor? anchor;
  late final GoRouter router;
  PermissionStatus status;
  PermissionStatus camera;
  var statusChecks = 0;
  var cameraRequests = 0;
  var settingsOpened = 0;

  Future<void> tapAr(WidgetTester tester) async {
    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
  }

  Future<void> tapArAndContinue(WidgetTester tester) async {
    await tapAr(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }
}

const _destinationId = '00000000-0000-4000-8000-000000000119';
final _fixture = File('test/fixtures/vec119_place.json').readAsStringSync();

void main() {
  testWidgets('selected destination uses fetched pose, never the spike door', (
    tester,
  ) async {
    final json = jsonDecode(_fixture) as Map<String, dynamic>;
    final place = json['place'] as Map<String, dynamic>;
    place['id'] = 'another-room';
    place['roomNumber'] = '120';
    place['indoor'] = {
      'mapCode': 'another-map',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC120',
      'floor': '2',
      'position': {'x': 1, 'y': 2, 'z': 3},
      'headingDeg': 90,
    };
    final harness = _Harness(
      status: PermissionStatus.granted,
      destinationId: 'another-room',
      fetch: (_) async => http.Response(jsonEncode(json), 200),
      bootClock: () async => fail('Launch without an anchor read the clock'),
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 1,
        durationMs: 1,
      ),
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(harness.fetchedIds, ['another-room']);
    expect(harness.fake.requests.single.toJson(), {
      'schemaVersion': 2,
      'room': '120',
      'mapCode': 'another-map',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC120',
      'floor': '2',
      'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
      'headingDeg': 90.0,
      'capabilities': ['signArrival'],
      'arToken': {
        'token': 'test-token',
        'expiresOn': '2026-01-01T00:30:00.000Z',
      },
    });
    expect(
      find.text('MultiSet localized this area. Room 120 is 0.5 m away.'),
      findsOneWidget,
    );
  });

  group('start floor question', () {
    var source = StreamController<PressureReading>.broadcast();
    var now = Duration.zero;
    DateTime wallClock() => DateTime.utc(2026).add(now);

    _Harness build({
      Future<http.Response> Function(http.Request)? mint,
      DateTime Function()? tokenClock,
      Duration Function()? tokenElapsed,
      Future<PermissionStatus>? pendingStatus,
      Future<PermissionStatus>? pendingPermission,
      Future<double?> Function()? bootClock,
      IndoorArLauncher? launcher,
      IndoorArRequest? request,
      IndoorArResult result = _cancelled,
      PermissionStatus status = PermissionStatus.granted,
      PermissionStatus camera = PermissionStatus.granted,
    }) {
      now = Duration.zero;
      source = StreamController<PressureReading>.broadcast();
      return _Harness(
        result: result,
        status: status,
        camera: camera,
        mint: mint,
        tokenClock: tokenClock,
        tokenElapsed: tokenElapsed,
        pendingStatus: pendingStatus,
        pendingPermission: pendingPermission,
        bootClock: bootClock,
        launcher: launcher,
        request: request,
        anchor: StartFloorAnchor(
          source: _StreamSource(source.stream),
          clock: () => now,
          wallClock: wallClock,
        ),
      );
    }

    Future<void> holdStill(
      WidgetTester tester,
      int seconds, {
      double hPa = 1000,
    }) async {
      for (var i = 0; i < seconds; i++) {
        now += const Duration(seconds: 1);
        source.add(PressureReading(hPa: hPa, timestamp: wallClock()));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    void useShortLandscape(WidgetTester tester) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 208);
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('asks first, reads no sensor, launches nothing', (
      tester,
    ) async {
      final harness = build();
      await harness.pump(tester);
      await harness.tapAr(tester);
      expect(find.textContaining('Which floor'), findsOneWidget);
      expect(source.hasListener, isFalse);
      expect(harness.fake.requests, isEmpty);
      expect(harness.statusChecks, 0);
    });

    testWidgets('confirmed floor held still sends the evidence', (
      tester,
    ) async {
      final launcher = _PendingLauncher();
      final harness = build(launcher: launcher);
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      expect(find.textContaining('Hold still'), findsOneWidget);
      expect(source.hasListener, isTrue);
      expect(launcher.requests, isEmpty);
      await holdStill(tester, 20);
      await tester.pump();
      final json = launcher.requests.single.toJson();
      expect(json['floor'], '1', reason: 'destination floor is untouched');
      expect(json['startFloor'], '2');
      expect(json['startFloorAgeS'], 20);
      expect(json['pressureSinceStart'], {
        'settled': true,
        'moved': false,
        'sampleAgeS': 0,
      });
      expect(source.hasListener, isFalse);
      launcher.resultReady.complete(_cancelled);
      await tester.pumpAndSettle();
    });

    for (final localize in [false, true]) {
      for (final (label, level, returns, sendHint) in [
        ('unchanged', null, false, false),
        ('returned', 999.5, true, false),
        ('out of range', 1003.5, false, false),
        ('usable', 999.5, false, true),
      ]) {
        final mode = localize ? 'localize' : 'door';
        testWidgets('$mode sends hint fields only for a usable delta ($label)', (
          tester,
        ) async {
          var clockReads = 0;
          final harness = build(
            request: localize
                ? IndoorArRequest.localize(
                    floor: '1',
                    mapCode: IndoorArRequest.buildMapCode,
                    frame: IndoorArRequest.buildFrame,
                  )
                : null,
            status: PermissionStatus.denied,
            bootClock: () async {
              clockReads++;
              return 4321.5;
            },
          );
          await harness.pump(tester);
          await harness.tapAr(tester);
          await tester.tap(find.text('Floor 2'));
          await tester.pump();
          await holdStill(tester, 20);
          if (level != null) await holdStill(tester, 21, hPa: level);
          if (returns) await holdStill(tester, 21);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          final request = harness.fake.requests.single;
          expect(request.isLocalize, localize);
          final wire = request.toJson();
          expect(clockReads, sendHint ? 1 : 0);
          expect(wire.containsKey('requestSentAtBootS'), sendHint);
          expect(wire['requestSentAtBootS'], sendHint ? 4321.5 : null);
          expect(wire['startFloor'], '2');
          expect(wire['pressureSinceStart'], {
            'settled': true,
            'moved': level != null,
            'sampleAgeS': 0,
            if (sendHint) 'deltaHpa': -0.5,
          });
        });
      }
    }

    for (final (label, bootClock) in <(String, Future<double?> Function()?)>[
      ('no boot clock', null),
      ('a boot clock that is unavailable', () async => null),
    ]) {
      testWidgets('$label sends evidence without a stamp', (tester) async {
        final launcher = _PendingLauncher();
        final harness = build(
          launcher: launcher,
          status: PermissionStatus.denied,
          bootClock: bootClock,
        );
        await harness.pump(tester);
        await harness.tapAr(tester);
        await tester.tap(find.text('Floor 2'));
        await tester.pump();
        await holdStill(tester, 20);
        await holdStill(tester, 21, hPa: 999.5);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        final json = launcher.requests.single.toJson();
        expect(json['startFloor'], '2');
        expect(json, isNot(contains('requestSentAtBootS')));
        expect(json['pressureSinceStart'], {
          'settled': true,
          'moved': true,
          'sampleAgeS': 0,
        });
        launcher.resultReady.complete(_cancelled);
        await tester.pumpAndSettle();
      });
    }

    for (final (name, lifecycle, wallDelay, elapsedDelay) in [
      ('inactive', AppLifecycleState.inactive, false, false),
      ('backgrounded', AppLifecycleState.paused, false, false),
      ('wall clock advances', AppLifecycleState.resumed, true, false),
      ('monotonic clock advances', AppLifecycleState.resumed, false, true),
    ]) {
      testWidgets('boot clock reply rechecks launch readiness ($name)', (
        tester,
      ) async {
        final clock = Completer<double?>();
        var clockReads = 0;
        var tokenTime = DateTime.utc(2026, 1, 1, 0, 28, 59, 900);
        var elapsed = Duration.zero;
        const delay = Duration(milliseconds: 200);
        final harness = build(
          status: PermissionStatus.denied,
          tokenClock: () => tokenTime,
          tokenElapsed: () => elapsed,
          bootClock: () {
            clockReads++;
            return clockReads == 1
                ? clock.future
                : Future.value(4280.5 + now.inMilliseconds / 1000);
          },
        );
        await harness.pump(tester);
        await harness.tapAr(tester);
        await tester.tap(find.text('Floor 2'));
        await tester.pump();
        await holdStill(tester, 20);
        await holdStill(tester, 21, hPa: 999.5);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(clockReads, 1);

        tester.binding.handleAppLifecycleStateChanged(lifecycle);
        if (wallDelay) tokenTime = tokenTime.add(delay);
        if (elapsedDelay) elapsed += delay;
        clock.complete(4321.5);
        await tester.pump();
        expect(harness.fake.requests, isEmpty);
        if (lifecycle != AppLifecycleState.resumed) {
          expect(find.text('Retry'), findsNothing);
          if (lifecycle == AppLifecycleState.inactive) {
            await holdStill(tester, 12, hPa: 999.5);
            const sampleAge = Duration(milliseconds: 250);
            now += sampleAge;
            await tester.pump(sampleAge);
            expect(clockReads, 1);
          }
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        if (lifecycle == AppLifecycleState.inactive) {
          final evidence = harness.fake.requests.single.startFloor!;
          expect(clockReads, 2);
          expect(evidence.requestSentAtBootS, 4333.75);
          expect(evidence.sampleAgeS, 0.25);
        } else {
          expect(clockReads, 1);
          expect(harness.fake.requests, isEmpty);
          expect(find.text('Retry'), findsOneWidget);
        }
        expect(source.hasListener, isFalse);
      });
    }

    for (final localize in [false, true]) {
      final mode = localize ? 'localize' : 'door';
      testWidgets('$mode refreshes a boot clock reply received after resume', (
        tester,
      ) async {
        final firstReply = Completer<double?>();
        var clockReads = 0;
        final harness = build(
          request: localize
              ? IndoorArRequest.localize(
                  floor: '1',
                  mapCode: IndoorArRequest.buildMapCode,
                  frame: IndoorArRequest.buildFrame,
                )
              : null,
          status: PermissionStatus.denied,
          bootClock: () {
            clockReads++;
            return clockReads == 1
                ? firstReply.future
                : Future.value(4280.5 + now.inMilliseconds / 1000);
          },
        );
        await harness.pump(tester);
        await harness.tapAr(tester);
        await tester.tap(find.text('Floor 2'));
        await tester.pump();
        await holdStill(tester, 20);
        await holdStill(tester, 21, hPa: 999.5);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        expect(clockReads, 1);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await holdStill(tester, 12, hPa: 999.5);
        const sampleAge = Duration(milliseconds: 250);
        now += sampleAge;
        await tester.pump(sampleAge);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(clockReads, 1);
        expect(harness.fake.requests, isEmpty);

        firstReply.complete(4321.5);
        await tester.pumpAndSettle();
        final request = harness.fake.requests.single;
        expect(request.isLocalize, localize);
        expect(clockReads, 2);
        final wire = request.toJson();
        expect(wire['requestSentAtBootS'], 4333.75);
        expect(wire['pressureSinceStart'], {
          'settled': true,
          'moved': true,
          'sampleAgeS': 0.25,
          'deltaHpa': -0.5,
        });
      });
    }

    testWidgets('a floor window that settles before resume gets a stamp', (
      tester,
    ) async {
      final mint = Completer<http.Response>();
      var clockReads = 0;
      final harness = build(
        mint: (_) => mint.future,
        bootClock: () async {
          clockReads++;
          return 4300 + now.inSeconds.toDouble();
        },
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 20);
      expect(harness.mintRequests, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await holdStill(tester, 1, hPa: 1000.5);
      mint.complete(http.Response(_mintedBody, 200));
      await tester.pump();
      await holdStill(tester, 20, hPa: 1000.5);
      expect(clockReads, 0);
      expect(harness.fake.requests, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final json = harness.fake.requests.single.toJson();
      expect(clockReads, 1);
      expect(json['requestSentAtBootS'], 4341);
      expect(json['pressureSinceStart'], {
        'settled': true,
        'moved': true,
        'sampleAgeS': 0,
        'deltaHpa': 0.5,
      });
    });

    testWidgets('floor and hold bypass actions scroll into reach', (
      tester,
    ) async {
      useShortLandscape(tester);
      var clockReads = 0;
      final harness = build(
        bootClock: () async {
          clockReads++;
          return null;
        },
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      final skip = find.text('Skip');
      expect(skip.hitTestable(), findsNothing);
      await tester.ensureVisible(skip);
      await tester.tap(skip);
      await tester.pumpAndSettle();
      expect(harness.fake.requests.single.startFloor, isNull);
      expect(source.hasListener, isFalse);

      await harness.tapAr(tester);
      final floor = find.text('Floor 2');
      await tester.ensureVisible(floor);
      await tester.tap(floor);
      await tester.pump();
      final continueEarly = find.text('Continue without waiting');
      await tester.ensureVisible(continueEarly);
      await tester.tap(continueEarly);
      await tester.pumpAndSettle();
      expect(harness.fake.requests, hasLength(2));
      expect(harness.fake.requests.last.startFloor, isNull);
      expect(source.hasListener, isFalse);
      expect(clockReads, 0);
    });

    testWidgets('localization retry and exit remain reachable', (tester) async {
      useShortLandscape(tester);
      final harness = build(
        result: const IndoorArResult(
          status: IndoorArStatus.localizationFailed,
          localizationQueries: 1,
          durationMs: 1,
        ),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      for (var attempt = 0; attempt < 2; attempt++) {
        final floor = find.text('Floor 2');
        await tester.ensureVisible(floor);
        await tester.tap(floor);
        await tester.pump();
        await holdStill(tester, 20);
        await tester.pumpAndSettle();
        final action = find.text(attempt == 0 ? 'Try again' : 'Back to map');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(harness.fake.requests, hasLength(2));
      expect(find.text('map'), findsOneWidget);
    });

    testWidgets('continuing without waiting sends no start floor', (
      tester,
    ) async {
      final mint = Completer<http.Response>();
      final harness = build(mint: (_) => mint.future);
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 19);
      await tester.tap(find.text('Continue without waiting'));
      await tester.pump();
      expect(harness.mintRequests, hasLength(1));
      expect(source.hasListener, isFalse);
      await holdStill(tester, 3);
      mint.complete(http.Response(_mintedBody, 200));
      await tester.pumpAndSettle();
      final json = harness.fake.requests.single.toJson();
      expect(json.keys, isNot(contains('startFloor')));
      expect(json.keys, isNot(contains('pressureSinceStart')));
    });

    testWidgets('stale floor, hold, and camera actions launch only once', (
      tester,
    ) async {
      final harness = build(status: PermissionStatus.denied);
      await harness.pump(tester);
      await harness.tapAr(tester);
      final skip = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
          .onPressed!;
      await tester.tap(find.text('Floor 2'));
      skip();
      await tester.pump();
      final continueEarly = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Continue without waiting'),
          )
          .onPressed!;
      await holdStill(tester, 20);
      continueEarly();
      await tester.pumpAndSettle();
      expect(harness.statusChecks, 1);

      final continueToCamera = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed!;
      continueToCamera();
      continueToCamera();
      await tester.pumpAndSettle();
      expect(harness.cameraRequests, 1);
      expect(harness.mintRequests, hasLength(1));
      expect(harness.fake.requests.single.toJson()['startFloor'], '2');
    });

    testWidgets('an expired hold stops sampling before the camera rationale', (
      tester,
    ) async {
      final harness = build(status: PermissionStatus.denied);
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 1, hPa: 1000.5);
      await holdStill(tester, 22);
      await tester.pumpAndSettle();
      expect(find.text(_rationale), findsOneWidget);
      expect(source.hasListener, isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(harness.fake.requests.single.startFloor, isNull);
    });

    for (final moved in [false, true]) {
      testWidgets(
        'camera rationale sends evidence only with a fresh window ($moved)',
        (tester) async {
          var clockReads = 0;
          final harness = build(
            status: PermissionStatus.denied,
            bootClock: () async {
              clockReads++;
              return 4321.5;
            },
          );
          await harness.pump(tester);
          await harness.tapAr(tester);
          await tester.tap(find.text('Floor 2'));
          await tester.pump();
          await holdStill(tester, 20);
          await tester.pumpAndSettle();
          expect(find.text(_rationale), findsOneWidget);
          expect(source.hasListener, isTrue);
          if (moved) {
            await holdStill(tester, 21, hPa: 1000.5);
          } else {
            const silence = Duration(seconds: 11);
            now += silence;
            await tester.pump(silence);
          }
          expect(source.hasListener, isTrue);
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          final evidence = harness.fake.requests.single.startFloor;
          expect(source.hasListener, isFalse);
          expect(clockReads, moved ? 1 : 0);
          if (moved) {
            expect(evidence?.moved, isTrue);
          } else {
            expect(evidence, isNull);
          }
        },
      );
    }

    for (final initiallyBlocked in [false, true]) {
      testWidgets(
        'permanent camera denial stops the sensor (initial: $initiallyBlocked)',
        (tester) async {
          final harness = build(
            status: initiallyBlocked
                ? PermissionStatus.permanentlyDenied
                : PermissionStatus.denied,
            camera: PermissionStatus.permanentlyDenied,
          );
          await harness.pump(tester);
          await harness.tapAr(tester);
          await tester.tap(find.text('Floor 2'));
          await tester.pump();
          await holdStill(tester, 20);
          await tester.pumpAndSettle();
          if (!initiallyBlocked) {
            await tester.tap(find.text('Continue'));
            await tester.pumpAndSettle();
          }
          expect(find.text('Open settings'), findsOneWidget);
          expect(source.hasListener, isFalse);
          expect(harness.mintRequests, isEmpty);
          expect(harness.fake.requests, isEmpty);
        },
      );
    }

    for (final duringHold in [false, true]) {
      testWidgets(
        'backgrounding invalidates floor evidence (holding: $duringHold)',
        (tester) async {
          final harness = build(status: PermissionStatus.denied);
          await harness.pump(tester);
          await harness.tapAr(tester);
          await tester.tap(find.text('Floor 2'));
          await tester.pump();
          await holdStill(tester, duringHold ? 1 : 20);
          expect(source.hasListener, isTrue);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          try {
            await tester.pump(const Duration(seconds: 10, milliseconds: 250));
            expect(source.hasListener, isFalse);
            expect(harness.statusChecks, duringHold ? 0 : 1);
          } finally {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          }
          await tester.pump();
          expect(harness.statusChecks, 1);
          expect(find.text(_rationale), findsOneWidget);
          await holdStill(tester, 22);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          final request = harness.fake.requests.single.toJson();
          expect(request, isNot(contains('pressureSinceStart')));
          expect(harness.statusChecks, 1);
        },
      );
    }

    testWidgets('Back during minting stops sampling and ignores the token', (
      tester,
    ) async {
      final mint = Completer<http.Response>();
      final harness = build(mint: (_) => mint.future);
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 20);
      expect(harness.mintRequests, hasLength(1));
      expect(source.hasListener, isTrue);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(
        find.byType(IndoorArLaunchScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(source.hasListener, isFalse);
      mint.complete(http.Response(_mintedBody, 200));
      await tester.pumpAndSettle();
      expect(harness.fake.requests, isEmpty);
      expect(find.text('map'), findsOneWidget);
    });

    for (final fromPrompt in [false, true]) {
      testWidgets(
        'permission received in background waits to mint (prompt: $fromPrompt)',
        (tester) async {
          final granted = Completer<PermissionStatus>();
          final harness = build(
            status: PermissionStatus.denied,
            pendingStatus: fromPrompt ? null : granted.future,
            pendingPermission: fromPrompt ? granted.future : null,
          );
          await harness.pump(tester);
          await harness.tapAr(tester);
          await tester.tap(find.text('Skip'));
          await tester.pump();
          if (fromPrompt) {
            await tester.tap(find.text('Continue'));
            await tester.pump();
          }
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          granted.complete(PermissionStatus.granted);
          await tester.pump();
          expect(harness.mintRequests, isEmpty);
          expect(harness.fake.requests, isEmpty);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(harness.mintRequests, hasLength(1));
          expect(harness.fake.requests, hasLength(1));
        },
      );
    }

    for (final outcome in [
      'interrupted',
      'rollback',
      'inactive rollback',
      'brief inactive',
      'late reply',
      'cancelled',
    ]) {
      testWidgets('interrupted token is rechecked on resume ($outcome)', (
        tester,
      ) async {
        final mint = Completer<http.Response>();
        var tokenTime = DateTime.utc(2026);
        var elapsed = Duration.zero;
        final harness = build(
          mint: (_) => mint.future,
          tokenClock: () => tokenTime,
          tokenElapsed: () => elapsed,
        );
        await harness.pump(tester);
        await harness.tapAr(tester);
        await tester.tap(find.text('Floor 2'));
        await tester.pump();
        await holdStill(tester, 20);
        expect(harness.mintRequests, hasLength(1));

        final brief = outcome == 'brief inactive';
        final inactiveOnly = brief || outcome == 'inactive rollback';
        tester.binding.handleAppLifecycleStateChanged(
          inactiveOnly ? AppLifecycleState.inactive : AppLifecycleState.paused,
        );
        if (outcome != 'late reply') {
          mint.complete(http.Response(_mintedBody, 200));
        }
        await tester.pump();
        expect(harness.fake.requests, isEmpty);
        expect(source.hasListener, inactiveOnly);

        if (brief) {
          elapsed = const Duration(seconds: 1);
          await tester.pump(elapsed);
        } else if (outcome == 'rollback' || outcome == 'inactive rollback') {
          elapsed = const Duration(minutes: 31);
          tokenTime = tokenTime.add(elapsed);
          await tester.pump(const Duration(minutes: 31));
          tokenTime = tokenTime.subtract(const Duration(minutes: 32));
        } else if (outcome == 'cancelled') {
          expect(await tester.binding.handlePopRoute(), isTrue);
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(harness.fake.requests, isEmpty);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        if (outcome == 'late reply') {
          mint.complete(http.Response(_mintedBody, 200));
        }
        await tester.pumpAndSettle();

        if (brief) {
          expect(harness.fake.requests, hasLength(1));
          expect(find.text('map'), findsOneWidget);
        } else {
          expect(harness.fake.requests, isEmpty);
          expect(
            find.text(outcome == 'cancelled' ? 'map' : 'Retry'),
            findsOneWidget,
          );
        }
        expect(harness.mintRequests, hasLength(1));
      });
    }

    testWidgets('Back during Unity ignores a late result', (tester) async {
      final launcher = _PendingLauncher();
      final harness = build(launcher: launcher);
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 20);
      expect(launcher.requests, hasLength(1));

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(
        find.byType(IndoorArLaunchScreen, skipOffstage: false),
        findsOneWidget,
      );
      launcher.resultReady.complete(_error('ARCORE_UNSUPPORTED'));
      await tester.pumpAndSettle();
      expect(find.text("This phone doesn't support AR."), findsNothing);
      expect(find.text('map'), findsOneWidget);
    });

    testWidgets('failure screen stops reading; retry asks again', (
      tester,
    ) async {
      var attempts = 0;
      final harness = build(
        mint: (_) async => ++attempts > 1
            ? http.Response(_mintedBody, 200)
            : http.Response('no', 500),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 20);
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't start AR. Check your connection and try again."),
        findsOneWidget,
      );
      expect(source.hasListener, isFalse);
      expect(harness.fake.requests, isEmpty);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Which floor'), findsOneWidget);
      expect(source.hasListener, isFalse);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      final json = harness.fake.requests.single.toJson();
      expect(json.keys, isNot(contains('startFloor')), reason: 'old answer');
    });

    testWidgets('localizationFailed after evidence re-asks, never reuses it', (
      tester,
    ) async {
      final harness = _Harness(
        status: PermissionStatus.granted,
        result: const IndoorArResult(
          status: IndoorArStatus.localizationFailed,
          localizationQueries: 1,
          durationMs: 1,
        ),
        anchor: () {
          now = Duration.zero;
          source = StreamController<PressureReading>.broadcast();
          return StartFloorAnchor(
            source: _StreamSource(source.stream),
            clock: () => now,
            wallClock: wallClock,
          );
        }(),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Floor 2'));
      await tester.pump();
      await holdStill(tester, 20);
      await tester.pumpAndSettle();
      expect(harness.fake.requests.single.toJson()['startFloor'], '2');
      expect(find.textContaining('Could not match'), findsOneWidget);
      expect(find.text('map'), findsNothing, reason: 'still on the screen');
      expect(source.hasListener, isFalse, reason: 'no pressure after Unity');

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Which floor'), findsOneWidget);
      expect(harness.fake.requests, hasLength(1), reason: 'no silent relaunch');
      await tester.tap(find.text('Floor 1'));
      await tester.pump();
      await holdStill(tester, 20);
      await tester.pumpAndSettle();
      final second = harness.fake.requests.last.toJson();
      expect(harness.fake.requests, hasLength(2));
      expect(second['startFloor'], '1', reason: 'new answer, not the old one');
      expect(second['startFloorAgeS'], 20);
    });

    for (final (name, delay, reasks) in [
      (
        'settled after a climb between samples',
        Duration(milliseconds: 100),
        true,
      ),
      ('unsettled current window', Duration.zero, false),
      ('unsettled at sample age limit', Duration(seconds: 10), false),
      ('over sample age limit', Duration(seconds: 10, microseconds: 1), false),
      ('over floor age limit', Duration(seconds: 1180, microseconds: 1), false),
    ]) {
      testWidgets('localization retry follows sent evidence ($name)', (
        tester,
      ) async {
        final harness = build(
          status: PermissionStatus.denied,
          result: const IndoorArResult(
            status: IndoorArStatus.localizationFailed,
            localizationQueries: 1,
            durationMs: 1,
          ),
        );
        await harness.pump(tester);
        await harness.tapAr(tester);
        await tester.tap(find.text('Floor 2'));
        await tester.pump();
        await holdStill(tester, 20);
        await tester.pumpAndSettle();
        if (reasks || delay == Duration.zero) {
          await holdStill(tester, 1, hPa: 999.75);
          if (reasks) await holdStill(tester, 20, hPa: 999.5);
        }
        now += delay;
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final request = harness.fake.requests.single;
        if (reasks) {
          expect(request.toJson()['floorEvidenceVersion'], 1);
          expect(request.toJson()['pressureSinceStart'], {
            'settled': true,
            'moved': true,
            'sampleAgeS': 0.1,
          });
        } else {
          expect(request.startFloor, isNull);
          expect(
            request.toJson(),
            request.withArToken(testArToken, startFloor: null).toJson(),
          );
        }
        expect(find.text('Try again'), reasks ? findsOneWidget : findsNothing);
        expect(find.text('map'), reasks ? findsNothing : findsOneWidget);
        if (reasks) {
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Which floor'), findsOneWidget);
          expect(source.hasListener, isFalse);
        }
      });
    }

    testWidgets('localizationFailed without evidence leaves as before', (
      tester,
    ) async {
      final harness = _Harness(
        status: PermissionStatus.granted,
        result: const IndoorArResult(
          status: IndoorArStatus.localizationFailed,
          localizationQueries: 1,
          durationMs: 1,
        ),
        anchor: StartFloorAnchor(
          source: _StreamSource(const Stream.empty()),
          clock: () => Duration.zero,
          wallClock: () => DateTime.utc(2026),
        ),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(
        harness.fake.requests.single.toJson(),
        isNot(contains('floorEvidenceVersion')),
      );
      expect(find.text('map'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('skip reads no sensor and sends no start floor', (
      tester,
    ) async {
      final harness = build();
      await harness.pump(tester);
      await harness.tapAr(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(source.hasListener, isFalse);
      final json = harness.fake.requests.single.toJson();
      expect(json.keys, isNot(contains('startFloor')));
    });
  });

  Future<void> expectArrival(
    WidgetTester tester, {
    required IndoorArResult result,
    String floor = '1',
    required Matcher shown,
  }) async {
    final json = jsonDecode(_fixture) as Map<String, dynamic>;
    ((json['place'] as Map<String, dynamic>)['indoor']
            as Map<String, dynamic>)['floor'] =
        floor;
    (json['place'] as Map<String, dynamic>)['floorNumber'] = floor;
    final harness = _Harness(
      status: PermissionStatus.granted,
      result: result,
      fetch: (_) async => http.Response(jsonEncode(json), 200),
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(harness.fake.requests, hasLength(1));
    expect(find.textContaining('119'), shown);
  }

  testWidgets('floor 3 destination launches', (tester) async {
    await expectArrival(
      tester,
      floor: '3',
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 1,
        durationMs: 1,
      ),
      shown: findsOneWidget,
    );
  });

  testWidgets('destination sign arrival shows no distance', (tester) async {
    await expectArrival(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        signRoom: 'VEC 119',
        localizationQueries: 1,
        durationMs: 1,
      ),
      shown: findsOneWidget,
    );
    expect(find.text('Found the 119 sign. You have arrived.'), findsOneWidget);
    expect(find.textContaining('m away'), findsNothing);
  });

  testWidgets('destination sign beats a placeholder distance', (tester) async {
    await expectArrival(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0,
        signRoom: 'VEC119',
        localizationQueries: 1,
        durationMs: 1,
      ),
      shown: findsOneWidget,
    );
    expect(find.textContaining('m away'), findsNothing);
  });

  testWidgets('another room sign keeps the measured distance', (tester) async {
    await expectArrival(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        signRoom: 'VEC120',
        localizationQueries: 1,
        durationMs: 1,
      ),
      shown: findsOneWidget,
    );
    expect(
      find.text('MultiSet localized this area. Room 119 is 0.5 m away.'),
      findsOneWidget,
    );
  });

  testWidgets('distance-less arrival for another room is unreadable', (
    tester,
  ) async {
    await expectArrival(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        signRoom: 'VEC120',
        localizationQueries: 1,
        durationMs: 1,
      ),
      shown: findsNothing,
    );
    expect(find.text('AR returned an unreadable result.'), findsOneWidget);
  });

  testWidgets('fetch failure offers retry without launching', (tester) async {
    var attempts = 0;
    final harness = _Harness(
      status: PermissionStatus.granted,
      fetch: (_) async {
        if (++attempts > 1) return http.Response(_fixture, 200);
        throw const SocketException('offline');
      },
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(
      find.text(
        'Could not load this place. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(harness.fake.requests, isEmpty);
    expect(harness.statusChecks, 0);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(harness.fetchedIds, [_destinationId, _destinationId]);
    expect(harness.fake.requests.single.toJson(), vec119Request().toJson());
    expect(find.text('map'), findsOneWidget);
  });

  for (final (name, response, message)
      in <(String, Future<http.Response> Function(http.Request), String)>[
        (
          'authentication failure',
          (_) async => http.Response('', 401),
          'Could not verify your account. Sign in again and retry.',
        ),
        (
          'place API failure',
          (_) async => http.Response('', 503),
          'Could not load place details. Try again.',
        ),
      ]) {
    testWidgets('$name does not ask for camera or mint an AR token', (
      tester,
    ) async {
      final harness = _Harness(
        status: PermissionStatus.granted,
        fetch: response,
      );
      await harness.pump(tester);
      await harness.tapAr(tester);

      expect(find.text(message), findsOneWidget);
      expect(harness.statusChecks, 0);
      expect(harness.cameraRequests, 0);
      expect(harness.mintRequests, isEmpty);
      expect(harness.fake.requests, isEmpty);
    });
  }

  for (final failure in ['missing indoor', 'malformed indoor']) {
    testWidgets('$failure scans without a door pose', (tester) async {
      final harness = _Harness(
        status: PermissionStatus.denied,
        fetch: (_) async {
          final json = jsonDecode(_fixture) as Map<String, dynamic>;
          final place = json['place'] as Map<String, dynamic>;
          place['indoor'] = failure == 'missing indoor'
              ? null
              : {'doorKey': 'broken'};
          return http.Response(jsonEncode(json), 200);
        },
      );
      await harness.pump(tester);
      await harness.tapAr(tester);
      expect(find.text(_scanRationale), findsOneWidget);
      expect(harness.fake.requests, isEmpty);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(harness.fake.requests.single.toJson(), {
        'schemaVersion': 2,
        'mode': 'localize',
        'room': '119',
        'floor': '1',
        'mapCode': 'MSET_XTBY7AM7ZK77',
        'frame': 'multiset-mapset',
        'arToken': {
          'token': 'test-token',
          'expiresOn': '2026-01-01T00:30:00.000Z',
        },
      });
      expect(
        harness.fake.requests.single.toJson().containsKey('position'),
        isFalse,
      );
    });
  }

  testWidgets('localization-only success does not claim room distance', (
    tester,
  ) async {
    final harness = _Harness(
      status: PermissionStatus.granted,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 1,
        durationMs: 1,
      ),
      fetch: (_) async {
        final json = jsonDecode(_fixture) as Map<String, dynamic>;
        (json['place'] as Map<String, dynamic>)['indoor'] = null;
        return http.Response(jsonEncode(json), 200);
      },
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(find.textContaining('localized this area.'), findsOneWidget);
    expect(find.textContaining('m away'), findsNothing);
  });

  testWidgets('missing destination cannot launch VEC localization', (
    tester,
  ) async {
    final harness = _Harness(
      destinationId: null,
      status: PermissionStatus.granted,
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(harness.fetchedIds, isEmpty);
    expect(harness.fake.requests, isEmpty);
    expect(harness.mintRequests, isEmpty);
  });

  testWidgets('unsupported building cannot launch VEC localization', (
    tester,
  ) async {
    final harness = _Harness(
      status: PermissionStatus.granted,
      fetch: (_) async {
        final json = jsonDecode(_fixture) as Map<String, dynamic>;
        (json['place'] as Map<String, dynamic>)['buildingCode'] = 'HC';
        (json['place'] as Map<String, dynamic>)['indoor'] = null;
        return http.Response(jsonEncode(json), 200);
      },
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(harness.fake.requests, isEmpty);
    expect(harness.mintRequests, isEmpty);
  });

  testWidgets('a granted camera launches straight away', (tester) async {
    final harness = _Harness(status: PermissionStatus.granted);
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(harness.cameraRequests, 0);
    expect(harness.fake.requests.single.toJson(), vec119Request().toJson());
    expect(find.text('map'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('mints one token over authenticated POST and hands it to Unity', (
    tester,
  ) async {
    final harness = _Harness(status: PermissionStatus.granted);
    await harness.pump(tester);
    await harness.tapAr(tester);

    final mint = harness.mintRequests.single;
    expect(mint.method, 'POST');
    expect(mint.url.toString(), 'https://example.test/indoor/ar-token');
    expect(mint.headers['Authorization'], 'Bearer session-1');
    expect(harness.fake.requests.single.arToken?.token, 'test-token');
  });

  testWidgets('a refused camera never spends a token request', (tester) async {
    final harness = _Harness(camera: PermissionStatus.denied);
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);

    expect(harness.mintRequests, isEmpty);
  });

  testWidgets('one 401 refreshes the session and retries once', (tester) async {
    var calls = 0;
    final harness = _Harness(
      status: PermissionStatus.granted,
      mint: (_) async => ++calls == 1
          ? http.Response('', 401)
          : http.Response(_mintedBody, 200),
    );
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(harness.session.refreshes, 1);
    expect(
      harness.mintRequests.last.headers['Authorization'],
      'Bearer session-2',
    );
    expect(harness.fake.requests, hasLength(1));
  });

  // The 401 case fails twice per fetch: the original call and its one refresh.
  for (final (name, failures, mint)
      in <(String, int, Future<http.Response> Function(http.Request))>[
        ('401', 2, (_) async => http.Response('', 401)),
        ('429', 1, (_) async => http.Response('', 429)),
        (
          '503',
          1,
          (_) async =>
              http.Response('{"error":{"code":"INDOOR_AR_UNAVAILABLE"}}', 503),
        ),
        (
          'network failure',
          1,
          (_) async => throw const SocketException('offline'),
        ),
        ('malformed body', 1, (_) async => http.Response('{"token":""}', 200)),
        (
          'expired token',
          1,
          (_) async => http.Response(
            jsonEncode({
              'token': 'test-token',
              'expiresOn': '2025-12-31T23:59:00.000Z',
            }),
            200,
          ),
        ),
        (
          'token about to expire',
          1,
          (_) async => http.Response(
            jsonEncode({
              'token': 'test-token',
              'expiresOn': '2026-01-01T00:00:30.000Z',
            }),
            200,
          ),
        ),
      ]) {
    testWidgets('token $name shows a retryable state and never launches', (
      tester,
    ) async {
      var attempts = 0;
      final harness = _Harness(
        status: PermissionStatus.granted,
        mint: (request) async => ++attempts > failures
            ? http.Response(_mintedBody, 200)
            : mint(request),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);

      expect(
        find.text("Couldn't start AR. Check your connection and try again."),
        findsOneWidget,
      );
      expect(harness.fake.requests, isEmpty);
      expect(find.text('map'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(harness.fake.requests.single.arToken?.token, 'test-token');
      expect(find.text('map'), findsOneWidget);
    });
  }

  testWidgets('the rationale shows before the system prompt', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(find.text(_rationale), findsOneWidget);
    expect(harness.cameraRequests, 0);
    expect(harness.fake.requests, isEmpty);
  });

  testWidgets('declining the rationale returns to the map without asking', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.tapAr(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(harness.cameraRequests, 0);
    expect(harness.fake.requests, isEmpty);
    expect(find.text('map'), findsOneWidget);
    expect(
      find.text('AR needs camera access. Tap the AR button to try again.'),
      findsOneWidget,
    );
  });

  testWidgets('allowing the camera launches once and returns to the map', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);

    expect(harness.cameraRequests, 1);
    expect(harness.fake.requests.single.toJson(), vec119Request().toJson());
    expect(find.text('map'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('denied camera shows a message and returns to the map', (
    tester,
  ) async {
    final harness = _Harness(camera: PermissionStatus.denied);
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);

    expect(harness.fake.requests, isEmpty);
    expect(find.text(_cameraOff), findsOneWidget);
    expect(find.text('map'), findsOneWidget);
  });

  testWidgets('every AR tap asks for the camera again', (tester) async {
    final harness = _Harness(camera: PermissionStatus.denied);
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);
    expect(harness.cameraRequests, 1);

    harness.camera = PermissionStatus.granted;
    await harness.tapArAndContinue(tester);

    expect(harness.cameraRequests, 2);
    expect(harness.fake.requests, hasLength(1));
  });

  testWidgets('a camera turned on in settings needs no second prompt', (
    tester,
  ) async {
    final harness = _Harness(camera: PermissionStatus.permanentlyDenied);
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    harness.status = PermissionStatus.granted;
    await harness.tapAr(tester);

    expect(harness.cameraRequests, 1);
    expect(harness.fake.requests, hasLength(1));
  });

  group('permanently denied camera', () {
    Future<_Harness> blocked(WidgetTester tester) async {
      final harness = _Harness(camera: PermissionStatus.permanentlyDenied);
      await harness.pump(tester);
      await harness.tapArAndContinue(tester);
      return harness;
    }

    testWidgets('offers settings and does not launch', (tester) async {
      final harness = await blocked(tester);

      expect(find.text(_cameraOff), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(harness.fake.requests, isEmpty);
    });

    testWidgets('opening settings returns to the map', (tester) async {
      final harness = await blocked(tester);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(harness.settingsOpened, 1);
      expect(find.text('map'), findsOneWidget);
    });

    testWidgets('can go back to the map without settings', (tester) async {
      final harness = await blocked(tester);
      await tester.tap(find.text('Back to map'));
      await tester.pumpAndSettle();

      expect(harness.settingsOpened, 0);
      expect(find.text('map'), findsOneWidget);
    });
  });

  testWidgets('a build without Unity says so and returns to the map', (
    tester,
  ) async {
    final harness = _Harness(
      status: PermissionStatus.granted,
      result: const IndoorArResult.unavailable(),
    );
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(find.text('AR is not included in this build.'), findsOneWidget);
    expect(find.text('map'), findsOneWidget);
  });

  for (final (code, text) in const [
    ('ARCORE_UNSUPPORTED', "This phone doesn't support AR."),
    ('UNITY_EXITED', 'AR closed unexpectedly.'),
    ('BAD_REQUEST', "AR couldn't start."),
    ('BAD_RESULT', 'AR returned an unreadable result.'),
    ('SOMETHING_NEW', 'AR failed (SOMETHING_NEW).'),
  ]) {
    testWidgets('error $code has its message and returns to the map', (
      tester,
    ) async {
      final harness = _Harness(
        status: PermissionStatus.granted,
        result: _error(code),
      );
      await harness.pump(tester);
      await harness.tapAr(tester);

      expect(find.text(text), findsOneWidget);
      expect(find.text('map'), findsOneWidget);
    });
  }

  testWidgets('a throwing launch returns to the map', (tester) async {
    final harness = _Harness(
      status: PermissionStatus.granted,
      launcher: _ThrowingLauncher(),
    );
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(find.text('AR closed unexpectedly.'), findsOneWidget);
    expect(find.text('map'), findsOneWidget);
  });

  testWidgets('a throwing launch after the prompt returns to the map', (
    tester,
  ) async {
    final harness = _Harness(launcher: _ThrowingLauncher());
    await harness.pump(tester);
    await harness.tapArAndContinue(tester);

    expect(find.text('AR closed unexpectedly.'), findsOneWidget);
    expect(find.text('map'), findsOneWidget);
  });

  testWidgets('on iOS it checks the camera and launches', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final harness = _Harness(status: PermissionStatus.granted);
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(harness.statusChecks, 1);
    expect(harness.fake.requests, hasLength(1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on other platforms it does not check the camera', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final harness = _Harness();
    await harness.pump(tester);
    await harness.tapAr(tester);

    expect(harness.statusChecks, 0);
    expect(harness.cameraRequests, 0);
    expect(harness.fake.requests, isEmpty);
    expect(
      find.text("AR mode isn't available on this device."),
      findsOneWidget,
    );
    expect(find.text('map'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
