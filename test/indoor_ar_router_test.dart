import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/data/indoor_ar_token_gateway.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/router/app_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'support/flow_fakes.dart' as flow;

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
const _indoorAr = MethodChannel(NativeIndoorArLauncher.channelName);

class _SignedInState extends AppState {
  @override
  bool get isAuthenticated => true;

  @override
  bool get isPasswordRecovery => false;
}

class _Tokens implements IndoorArTokenGateway {
  int calls = 0;
  bool fail = false;

  @override
  Future<IndoorArToken> fetch() async {
    calls++;
    if (fail) throw const IndoorArTokenException(401);
    return IndoorArToken(
      token: 'router-test-token',
      expiresOn: DateTime.now().add(const Duration(minutes: 10)),
    );
  }
}

CampusPlace _vecRoom(
  String room,
  String floor,
  IndoorArVector3 position,
  double headingDeg, {
  String? id,
}) => CampusPlace(
  id: id ?? 'vec-$room',
  type: CampusDestinationType.room,
  title: 'VEC $room',
  subtitle: 'Vivian Engineering Center · Floor $floor',
  source: 'csulb',
  buildingCode: 'VEC',
  roomNumber: room,
  floorNumber: floor,
  indoor: IndoorDoorPose(
    mapCode: IndoorArRequest.buildMapCode,
    frame: IndoorArRequest.buildFrame,
    doorKey: 'VEC$room',
    floor: floor,
    position: position,
    headingDeg: headingDeg,
  ),
);

// Backend poses; deliberately different from the bundled scan asset.
List<CampusPlace> _vecRooms() => [
  _vecRoom(
    '119',
    '1',
    const IndoorArVector3(-5.7651, -1.8186, 22.6689),
    185.36,
  ),
  _vecRoom('218', '2', const IndoorArVector3(1.25, -1.5, 9.5), 90),
];

class _FailingSearch extends flow.FakeSearchGateway {
  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async => throw const CampusSearchException(
    failure: CampusSearchFailure.offline,
    message: 'offline',
  );
}

class _DelayedSearch extends flow.FakeSearchGateway {
  final pending = Completer<List<CampusPlace>>();

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) => pending.future;
}

class _Harness {
  _Harness({flow.FakeSearchGateway? search})
    : search = search ?? (flow.FakeSearchGateway()..results = _vecRooms());

  final tokens = _Tokens();
  final requests = <Map<String, dynamic>>[];
  final flow.FakeSearchGateway search;
  PermissionStatus camera = PermissionStatus.granted;
  int permissionRequests = 0;
  late final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Keep cached asset futures inside each test's async zone.
    rootBundle.evict('assets/indoor/vec_floors1and2.json');
    final appState = _SignedInState();
    final controller = flow.build(search: search);
    router = createAppRouter(
      appState,
      initialLocation: '/buildings/vec',
      indoorArTokenGateway: tokens,
    );
    addTearDown(appState.dispose);
    addTearDown(controller.search.dispose);
    addTearDown(controller.dispose);
    addTearDown(router.dispose);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissions, (call) async {
      if (call.method == 'checkPermissionStatus') {
        expect(call.arguments, Permission.camera.value);
        return camera.index;
      }
      if (call.method == 'requestPermissions') {
        permissionRequests++;
        return {Permission.camera.value: camera.index};
      }
      throw StateError('Unexpected permission call: ${call.method}');
    });
    messenger.setMockMethodCallHandler(_indoorAr, (call) async {
      expect(call.method, 'launch');
      requests.add(
        jsonDecode(call.arguments as String) as Map<String, dynamic>,
      );
      return '{"status":"cancelled","localizationQueries":0,"durationMs":1}';
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<NavigationFlowController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final roomAction = find.textContaining('Verify location near room ');
    for (
      var attempt = 0;
      attempt < 50 && roomAction.evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(roomAction, findsOneWidget);
  }

  Future<void> tapFloorPlanAr(WidgetTester tester) async {
    final button = find.textContaining('Verify location near room ');
    await tester.scrollUntilVisible(
      button,
      -100,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissions, null);
    messenger.setMockMethodCallHandler(_indoorAr, null);
  });

  for (final floor in [1, 2]) {
    testWidgets(
      'floor $floor room reaches Unity through the production router',
      (tester) async {
        final harness = _Harness();
        await harness.pump(tester);
        if (floor == 2) {
          await tester.ensureVisible(find.text('Floor 2'));
          await tester.tap(find.text('Floor 2'));
          await tester.pumpAndSettle();
        }
        await harness.tapFloorPlanAr(tester);
        expect(harness.requests, hasLength(1));
        final request = harness.requests.single;
        final place = harness.search.results.singleWhere(
          (item) => item.floorNumber == '$floor',
        );
        final pose = place.indoor!;
        expect(request['schemaVersion'], IndoorArRequest.schemaVersion);
        expect(request['floor'], '$floor');
        expect(request['doorKey'], pose.doorKey);
        expect(request['position'], pose.position.toJson());
        expect(request['headingDeg'], pose.headingDeg);
        expect(request['mapCode'], IndoorArRequest.buildMapCode);
        expect(request['frame'], IndoorArRequest.buildFrame);
        expect(request['arToken']['token'], 'router-test-token');
        expect(harness.tokens.calls, 1);
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          '/buildings/vec',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets('map room button sends the same request as autocomplete', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.tapFloorPlanAr(tester);
    final fromMap = {...harness.requests.single}..remove('arToken');
    harness.requests.clear();
    harness.router.push('/ar?destination=vec-119');
    await tester.pumpAndSettle();
    expect({...harness.requests.single}..remove('arToken'), fromMap);
    // Coordinates are the backend's, not the bundled scan's.
    expect(fromMap['position'], {'x': -5.7651, 'y': -1.8186, 'z': 22.6689});
    expect(fromMap['headingDeg'], 185.36);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  final unsafeLookups = <String, List<CampusPlace>>{
    'no matching record': const [],
    'only another floor': [
      _vecRoom('119', '2', const IndoorArVector3(1, 1, 1), 10),
    ],
    'only another room': [
      _vecRoom('120', '1', const IndoorArVector3(1, 1, 1), 10),
    ],
    'ambiguous records': [
      _vecRoom('119', '1', const IndoorArVector3(1, 1, 1), 10, id: 'a'),
      _vecRoom('119', '1', const IndoorArVector3(2, 2, 2), 20, id: 'b'),
    ],
  };
  for (final entry in unsafeLookups.entries) {
    testWidgets('map room button does not launch AR for ${entry.key}', (
      tester,
    ) async {
      final harness = _Harness(
        search: flow.FakeSearchGateway()..results = entry.value,
      );
      await harness.pump(tester);
      await harness.tapFloorPlanAr(tester);
      expect(find.textContaining("Couldn't match room 119"), findsOneWidget);
      expect(harness.tokens.calls, 0);
      expect(harness.requests, isEmpty);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/buildings/vec',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('map room button does not launch AR when lookup fails', (
    tester,
  ) async {
    final harness = _Harness(search: _FailingSearch());
    await harness.pump(tester);
    await harness.tapFloorPlanAr(tester);
    expect(find.textContaining("Couldn't look up room 119"), findsOneWidget);
    expect(harness.tokens.calls, 0);
    expect(harness.requests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final selection in ['floor', 'room chip', 'map marker']) {
    testWidgets('changing $selection discards pending room lookup', (
      tester,
    ) async {
      final search = _DelayedSearch()..results = _vecRooms();
      final harness = _Harness(search: search);
      await harness.pump(tester);
      await tester.tap(find.textContaining('Verify location near room '));
      await tester.pump();

      if (selection == 'floor') {
        await tester.tap(find.text('Floor 2'));
      } else if (selection == 'room chip') {
        final chip = find.widgetWithText(ActionChip, '120');
        await tester.scrollUntilVisible(
          chip,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(chip);
      } else {
        final map = find
            .descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(CustomPaint),
            )
            .first;
        await tester.ensureVisible(find.byType(InteractiveViewer));
        final render = tester.renderObject<RenderBox>(map);
        await tester.tapAt(
          render.localToGlobal(
            Offset(render.size.width * .19, render.size.height * .18),
          ),
        );
      }
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('Verify location near room '),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Verify location near room 119'),
        findsNothing,
      );
      search.pending.complete(_vecRooms());
      await tester.pumpAndSettle();
      expect(harness.tokens.calls, 0);
      expect(harness.requests, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/buildings/vec',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('floor-plan entry keeps camera consent before token minting', (
    tester,
  ) async {
    final harness = _Harness()..camera = PermissionStatus.denied;
    await harness.pump(tester);
    await harness.tapFloorPlanAr(tester);
    expect(find.text('Continue'), findsOneWidget);
    expect(harness.tokens.calls, 0);
    expect(harness.requests, isEmpty);
    harness.camera = PermissionStatus.granted;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(harness.permissionRequests, 1);
    expect(harness.tokens.calls, 1);
    expect(harness.requests, hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('floor-plan entry cannot launch when token minting fails', (
    tester,
  ) async {
    final harness = _Harness();
    harness.tokens.fail = true;
    await harness.pump(tester);
    await harness.tapFloorPlanAr(tester);
    expect(harness.tokens.calls, 1);
    expect(harness.requests, isEmpty);
    expect(
      find.text("Couldn't start AR. Check your connection and try again."),
      findsOneWidget,
    );
    harness.tokens.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(harness.tokens.calls, 2);
    expect(harness.requests, hasLength(1));
    expect(harness.requests.single['doorKey'], 'VEC119');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('explicit localization request sends no destination pose', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    harness.router.push(
      '/ar',
      extra: IndoorArRequest.localize(
        floor: '2',
        mapCode: IndoorArRequest.buildMapCode,
        frame: IndoorArRequest.buildFrame,
      ),
    );
    await tester.pumpAndSettle();
    final request = harness.requests.single;
    expect(request['mode'], IndoorArRequest.localizeMode);
    expect(request.containsKey('position'), isFalse);
    expect(request.containsKey('doorKey'), isFalse);
    expect(request.containsKey('headingDeg'), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final unsupported in [
    (
      floor: '4',
      mapCode: IndoorArRequest.buildMapCode,
      frame: IndoorArRequest.buildFrame,
    ),
    (floor: '1', mapCode: 'another-map', frame: IndoorArRequest.buildFrame),
    (floor: '1', mapCode: IndoorArRequest.buildMapCode, frame: 'another-frame'),
  ]) {
    testWidgets('unsupported explicit request $unsupported stays unavailable', (
      tester,
    ) async {
      final harness = _Harness();
      await harness.pump(tester);
      harness.router.push(
        '/ar',
        extra: IndoorArRequest.localize(
          floor: unsupported.floor,
          mapCode: unsupported.mapCode,
          frame: unsupported.frame,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Indoor AR isn't available for this room"),
        findsOneWidget,
      );
      expect(harness.tokens.calls, 0);
      expect(harness.requests, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets(
    'normal destination without a pose still localizes through router',
    (tester) async {
      final harness = _Harness();
      harness.search.results = const [
        CampusPlace(
          id: 'vec-room-without-pose',
          type: CampusDestinationType.room,
          title: 'VEC 120',
          subtitle: 'VEC',
          source: 'test',
          buildingCode: 'VEC',
          roomNumber: '120',
          floorNumber: '1',
        ),
      ];
      await harness.pump(tester);
      harness.router.push('/ar?destination=vec-room-without-pose');
      await tester.pumpAndSettle();
      final request = harness.requests.single;
      expect(request['mode'], IndoorArRequest.localizeMode);
      expect(request['room'], '120');
      expect(request.containsKey('position'), isFalse);
      expect(request.containsKey('doorKey'), isFalse);
      expect(request.containsKey('headingDeg'), isFalse);
      expect(harness.tokens.calls, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
