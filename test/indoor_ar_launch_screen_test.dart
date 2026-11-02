import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/campus_search_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_launch_screen.dart';
import 'support/indoor_ar_fixtures.dart';
import 'package:permission_handler/permission_handler.dart';

const _rationale =
    'Allow camera access so NaviPet can show arrows over the floor around you.';
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

/// The map stands in as a page with an AR tap target, so each tap opens the
/// screen fresh, as it does in the app.
class _Harness {
  _Harness({
    IndoorArResult result = _cancelled,
    this.status = PermissionStatus.denied,
    this.camera = PermissionStatus.granted,
    IndoorArLauncher? launcher,
    String? destinationId = _destinationId,
    Future<http.Response> Function(http.Request)? fetch,
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
            destinationId: state.uri.queryParameters['destination'],
            gateway: HttpCampusSearchGateway(
              baseUrl: 'https://example.test',
              client: MockClient((request) async {
                fetchedIds.add(request.url.pathSegments.last);
                return fetch != null
                    ? await fetch(request)
                    : http.Response(_fixture, 200);
              }),
            ),
            cameraStatus: () async {
              statusChecks++;
              return status;
            },
            requestCamera: () async {
              cameraRequests++;
              return camera;
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
  final FakeIndoorArLauncher fake;
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
    );
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(harness.fetchedIds, ['another-room']);
    expect(harness.fake.requests.single.toJson(), {
      'schemaVersion': 1,
      'room': '120',
      'mapCode': 'another-map',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC120',
      'floor': '2',
      'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
      'headingDeg': 90.0,
    });
  });

  for (final failure in [
    'missing indoor',
    'fetch failure',
    'malformed indoor',
  ]) {
    testWidgets(
      '$failure offers retry without launching or asking for camera',
      (tester) async {
        var attempts = 0;
        final harness = _Harness(
          status: PermissionStatus.granted,
          fetch: (_) async {
            if (++attempts > 1) return http.Response(_fixture, 200);
            if (failure == 'fetch failure') {
              throw const SocketException('offline');
            }
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
        expect(
          find.text("Indoor AR isn't available for this room"),
          findsOneWidget,
        );
        expect(harness.fake.requests, isEmpty);
        expect(harness.statusChecks, 0);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(harness.fetchedIds, [_destinationId, _destinationId]);
        expect(harness.fake.requests.single.toJson(), vec119Request().toJson());
        expect(find.text('map'), findsOneWidget);
      },
    );
  }

  testWidgets('missing destination never fetches or launches', (tester) async {
    final harness = _Harness(destinationId: null);
    await harness.pump(tester);
    await harness.tapAr(tester);
    expect(
      find.text("Indoor AR isn't available for this room"),
      findsOneWidget,
    );
    expect(harness.fetchedIds, isEmpty);
    expect(harness.fake.requests, isEmpty);
    await tester.tap(find.text('Back to map'));
    await tester.pumpAndSettle();
    expect(find.text('map'), findsOneWidget);
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

  testWidgets('off Android it does not check the camera', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
