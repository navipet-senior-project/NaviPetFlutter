import 'dart:convert';
import 'dart:io';

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

class _Harness {
  final tokens = _Tokens();
  final requests = <Map<String, dynamic>>[];
  final search = flow.FakeSearchGateway();
  PermissionStatus camera = PermissionStatus.granted;
  int permissionRequests = 0;
  late final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
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
        final map =
            jsonDecode(
                  File('assets/indoor/vec_floors1and2.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final door = (map['objects'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((object) => object['id'] == request['doorKey']);
        expect(request['schemaVersion'], IndoorArRequest.schemaVersion);
        expect(request['floor'], '$floor');
        expect(door['floorId'], endsWith('$floor'));
        expect(request['position'], door['position']);
        expect(request['headingDeg'], door['rotationY']);
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
      floor: '3',
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
