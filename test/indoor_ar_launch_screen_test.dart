import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_launch_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/flow_fakes.dart';

const _vec119Id = '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f';

CampusPlace _vec119({bool indoor = true}) => CampusPlace.fromJson({
  'id': _vec119Id,
  'type': 'room',
  'title': 'VEC 119',
  'subtitle': 'VEC',
  'source': 'csulb',
  'roomNumber': '119',
  if (indoor)
    'indoor': {
      'mapCode': 'MSET_XTBY7AM7ZK77',
      'frame': 'multiset-mapset',
      'doorKey': 'VEC119',
      'floor': '1',
      'position': {'x': -5.7651, 'y': -1.8186, 'z': 22.6689},
      'headingDeg': 185.36,
    },
});

Future<FakeIndoorArLauncher> _pump(
  WidgetTester tester, {
  String id = _vec119Id,
  List<CampusPlace>? places,
  PermissionStatus camera = PermissionStatus.granted,
  IndoorArResult? result,
}) async {
  final launcher = FakeIndoorArLauncher(
    result: result ?? const IndoorArResult.unavailable(),
  );
  final gateway = FakeSearchGateway()..results = places ?? [_vec119()];
  await tester.pumpWidget(
    MaterialApp(
      home: IndoorArLaunchScreen(
        destinationId: id,
        launcher: launcher,
        gateway: gateway,
        requestCamera: () async => camera,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return launcher;
}

IndoorArResult _error(String code) => IndoorArResult(
  status: IndoorArStatus.error,
  errorCode: code,
  localizationQueries: 0,
  durationMs: 1,
);

void main() {
  testWidgets('launches the loaded door and shows the distance', (
    tester,
  ) async {
    final launcher = await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.84,
        localizationQueries: 2,
        durationMs: 30000,
      ),
    );
    expect(find.text('VEC 119'), findsOneWidget);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(launcher.requests.single.doorKey, 'VEC119');
    expect(find.text('Pin was 0.8 m from you'), findsOneWidget);
  });

  testWidgets('a room without an indoor pose cannot start AR', (tester) async {
    await _pump(tester, places: [_vec119(indoor: false)]);
    expect(
      find.text("Indoor AR isn't available for this room"),
      findsOneWidget,
    );
    expect(find.text('Start AR'), findsNothing);
  });

  testWidgets('an empty destination id cannot start AR', (tester) async {
    await _pump(tester, id: '');
    expect(
      find.text("Indoor AR isn't available for this room"),
      findsOneWidget,
    );
  });

  testWidgets('a failed place load offers Retry', (tester) async {
    await _pump(tester, places: const []);
    expect(find.text("Couldn't load this room."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('denied camera does not launch', (tester) async {
    final launcher = await _pump(tester, camera: PermissionStatus.denied);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(launcher.requests, isEmpty);
    expect(
      find.text('NaviPet needs the camera to show the door pin.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('permanently denied camera offers settings', (tester) async {
    await _pump(tester, camera: PermissionStatus.permanentlyDenied);
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('localization failure offers Retry', (tester) async {
    await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.localizationFailed,
        localizationQueries: 6,
        durationMs: 60000,
      ),
    );
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't find your position"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('cancelled shows nothing, unavailable explains', (tester) async {
    final launcher = await _pump(
      tester,
      result: const IndoorArResult(
        status: IndoorArStatus.cancelled,
        localizationQueries: 0,
        durationMs: 1,
      ),
    );
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pin was'), findsNothing);
    expect(find.text('Start AR'), findsOneWidget);

    launcher.result = const IndoorArResult.unavailable();
    await tester.tap(find.text('Start AR'));
    await tester.pumpAndSettle();
    expect(find.text('AR not included in this build'), findsOneWidget);
  });

  for (final (code, text) in [
    ('ARCORE_UNSUPPORTED', "This phone doesn't support AR."),
    ('MULTISET_AUTH', "Couldn't connect to the indoor map service."),
    ('NETWORK', 'No internet connection. Check it and try again.'),
    ('UNITY_EXITED', 'AR closed unexpectedly.'),
    ('BAD_REQUEST', "This room's AR data is invalid."),
    ('MAP_MISMATCH', "This room's AR data is for a different map."),
    ('BAD_RESULT', 'AR returned an unreadable result.'),
    ('SOMETHING_NEW', 'AR failed (SOMETHING_NEW)'),
  ]) {
    testWidgets('error $code has its own message', (tester) async {
      await _pump(tester, result: _error(code));
      await tester.tap(find.text('Start AR'));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    });
  }
}
