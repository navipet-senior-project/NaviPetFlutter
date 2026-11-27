import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils, RenderParagraph;
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
  _vecRoom('301', '3', const IndoorArVector3(-12.4, 6.5, 26.9), 0),
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
    rootBundle.evict('assets/indoor/vec_floors123.json');
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
    final roomAction = find.text('Verify with AR');
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
    await tester.pumpAndSettle();
  }

  Future<void> tapFloorPlanAr(WidgetTester tester) async {
    await tester.tap(find.text('Verify with AR'));
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

  for (final floor in [1, 2, 3]) {
    testWidgets(
      'floor $floor room reaches Unity through the production router',
      (tester) async {
        final harness = _Harness();
        await harness.pump(tester);
        if (floor != 1) {
          await tester.tap(find.text('Floor $floor'));
          await tester.pumpAndSettle();
          // Switching floors clears the selection; pick a door on this floor.
          final door = floor == 2 ? '218' : '301';
          await tester.tapAt(
            tester.getCenter(find.byKey(ValueKey('door-$door'))),
          );
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

  testWidgets('floor 2 paints the west access with a neutral marker', (
    tester,
  ) async {
    await _Harness().pump(tester);
    await tester.tap(find.text('Floor 2'));
    await tester.pumpAndSettle();

    final plan = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(CustomPaint),
    );
    final marker = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          (-29.62105941772461 + 36) * 10,
          (35 - 21.350000381469727) * 10,
        ),
        width: 15,
        height: 15,
      ),
      const Radius.circular(3.5),
    );
    final canvas = TestRecordingCanvas();
    tester
        .widget<CustomPaint>(plan)
        .painter!
        .paint(canvas, tester.getSize(plan));
    final westMarker = canvas.invocations
        .map((call) => call.invocation)
        .singleWhere(
          (call) =>
              call.memberName == #drawRRect &&
              call.positionalArguments.first == marker,
        );
    expect(
      (westMarker.positionalArguments[1] as Paint).color.toARGB32(),
      0xFF5D6B82,
    );
  });

  testWidgets('floor 3 shows doors and floors 4–5 stay pending', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await tester.tap(find.text('Floor 3'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a room'), findsOneWidget);
    expect(
      find.text('Tap a door on the map or pick a room from the list.'),
      findsOneWidget,
    );
    expect(find.text('9 pinned · 0 directory-only'), findsOneWidget);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('door-301'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Door on scan'), findsOneWidget);
    expect(find.text('Verify with AR'), findsOneWidget);

    final pending = find.text(
      'Corridors are traced from the building scan. Door pin points for this floor are still coming.',
    );
    for (final floor in [5, 4]) {
      await tester.tap(find.text('Floor $floor'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Select room')), findsNothing);
      expect(find.text('0 pinned · 7 directory-only'), findsOneWidget);
      expect(pending, findsOneWidget);
      expect(find.text('Pick a room from the directory.'), findsOneWidget);

      await tester.tap(find.byTooltip('Full-screen map'));
      await tester.pumpAndSettle();
      expect(pending, findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Select room')), findsNothing);
      await tester.tap(find.byTooltip('Exit full-screen map'));
      await tester.pumpAndSettle();
    }
    final chip = find.text('417');
    await tester.scrollUntilVisible(
      chip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('AR unavailable here'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    expect(harness.requests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('narrow map controls leave door taps and actions available', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _Harness().pump(tester);

    Finder door(String room) => find.byKey(ValueKey('door-$room'));
    final viewer = find.byType(InteractiveViewer);
    Offset pinAt(Offset canvasPoint) {
      final controller = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      return tester.getTopLeft(viewer) +
          MatrixUtils.transformPoint(controller.value, canvasPoint);
    }

    const pin119 = Offset(279.44, 138.28);
    const pin120 = Offset(251.87, 137.68);
    const pin128 = Offset(571.55, 107.73);
    const pin132 = Offset(552.36, 136.43);
    const pin136 = Offset(456.46, 135.82);
    final exposedDoors = find.bySemanticsLabel(RegExp(r'^Select room \d+$'));
    Key? exploredDoorAt(Offset point) {
      final hits = exposedDoors.evaluate().where((element) {
        final box = element.renderObject! as RenderBox;
        final node = tester.getSemantics(find.byWidget(element.widget));
        return node.rect.contains(box.globalToLocal(point));
      });
      return hits.isEmpty ? null : hits.single.widget.key;
    }

    final asset =
        jsonDecode(
              await rootBundle.loadString('assets/indoor/vec_floors123.json'),
            )
            as Map<String, dynamic>;
    final floorDoors = (asset['objects'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (entry) => entry['type'] == 'door' && entry['floorId'] == 'floor_1',
        );
    final centers = <Key, Offset>{
      for (final item in floorDoors)
        ValueKey('door-${(item['id'] as String).substring(3)}'): pinAt(
          Offset(
            ((item['position']['x'] as num).toDouble() + 36) * 10,
            (35 - (item['position']['z'] as num).toDouble()) * 10,
          ),
        ),
    };
    expect(exposedDoors, findsNWidgets(centers.length));
    final bounds = <Rect>[];
    for (final entry in centers.entries) {
      expect(exploredDoorAt(entry.value), entry.key);
      final region = tester.getRect(find.byKey(entry.key));
      expect(bounds.any(region.overlaps), isFalse);
      bounds.add(region);
    }

    await tester.tapAt(Offset.lerp(pinAt(pin120), pinAt(pin119), .4)!);
    await tester.pumpAndSettle();
    expect(find.text('Room 120'), findsOneWidget);

    final above132 = pinAt(pin132) - const Offset(0, 8);
    for (final (room, point) in [
      ('119', pinAt(pin119)),
      ('120', pinAt(pin120)),
      ('132', above132),
    ]) {
      expect(exploredDoorAt(point), ValueKey('door-$room'));
    }
    await tester.tapAt(above132);
    await tester.pumpAndSettle();
    expect(find.text('Room 132'), findsOneWidget);

    await tester.tapAt(pinAt(pin128));
    await tester.pumpAndSettle();
    expect(find.text('Room 128'), findsOneWidget);

    final beside132 = pinAt(pin132) + const Offset(4, -1);
    await tester.tapAt(beside132);
    await tester.pumpAndSettle();
    expect(find.text('Room 132'), findsOneWidget);

    final center = pinAt(pin136);
    expect(exploredDoorAt(center + const Offset(0, 21)), isNull);
    await tester.tapAt(center + const Offset(0, 21));
    await tester.pumpAndSettle();
    expect(find.text('Room 132'), findsOneWidget);
    final corner136 = center + const Offset(-18, -18);
    await tester.tapAt(corner136);
    await tester.pumpAndSettle();
    expect(find.text('Room 132'), findsOneWidget);
    expect(
      exploredDoorAt(center + const Offset(0, 12)),
      const ValueKey('door-136'),
    );
    await tester.tapAt(center + const Offset(0, 12));
    await tester.pumpAndSettle();
    expect(find.text('Room 136'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
    }
    final visible = tester.getRect(viewer);
    expect(door('128'), findsNothing);
    await tester.tapAt(Offset(visible.right - 1, pinAt(pin128).dy));
    await tester.pumpAndSettle();
    expect(find.text('Room 136'), findsOneWidget);

    await tester.tap(find.byTooltip('Full-screen map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    final beforePan = pinAt(pin120);
    await tester.drag(viewer, const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(pinAt(pin120).dx, greaterThan(beforePan.dx));
    final near120 = pinAt(pin120) + const Offset(5, 0);
    expect(exploredDoorAt(near120), const ValueKey('door-120'));
    await tester.tapAt(near120);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(door('120')), isSemantics(isSelected: true));

    final accessibilityDoor = tester.getSemantics(door('119'));
    accessibilityDoor.owner!.performAction(
      accessibilityDoor.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(door('119')), isSemantics(isSelected: true));
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final focalPoint = tester.getSize(viewer).center(Offset.zero);
    controller.value = Matrix4.identity()
      ..translateByDouble(
        focalPoint.dx - pin120.dx * 4,
        focalPoint.dy - pin120.dy * 4,
        0,
        1,
      )
      ..scaleByDouble(4, 4, 4, 1);
    await tester.pumpAndSettle();
    await tester.tapAt(pinAt(pin120) + const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(door('120')), isSemantics(isSelected: false));
    final insideZoomedPin = pinAt(pin120) + const Offset(0, 24);
    expect(exploredDoorAt(insideZoomedPin), const ValueKey('door-120'));
    await tester.tapAt(insideZoomedPin);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(door('120')), isSemantics(isSelected: true));
    await tester.tap(find.byTooltip('Exit full-screen map'));
    await tester.pumpAndSettle();
    expect(find.text('Room 120'), findsOneWidget);
  });

  testWidgets('pinch zooms out after the button in both map layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _Harness().pump(tester);

    final viewer = find.byType(InteractiveViewer);
    double scale() => tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    for (final expanded in [false, true]) {
      if (expanded) {
        await tester.tap(find.byTooltip('Full-screen map'));
        await tester.pumpAndSettle();
      }
      final fit = scale();
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      final afterButton = scale();
      expect(afterButton, lessThan(fit));

      final center = tester.getCenter(viewer);
      final left = await tester.startGesture(center - const Offset(80, 0));
      final right = await tester.startGesture(center + const Offset(80, 0));
      await tester.pump();
      await left.moveBy(const Offset(65, 0));
      await right.moveBy(const Offset(-65, 0));
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(scale(), closeTo(.2, .001));
    }
  });

  testWidgets('full-screen pan and zoom keep a floor 3 corridor visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _Harness().pump(tester);
    await tester.tap(find.text('Floor 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-screen map'));
    await tester.pumpAndSettle();

    final viewer = find.byType(InteractiveViewer);
    final plan = find.descendant(
      of: viewer,
      matching: find.byType(CustomPaint),
    );
    final viewport = tester.getRect(viewer);
    final canvas = TestRecordingCanvas();
    tester
        .widget<CustomPaint>(plan)
        .painter!
        .paint(canvas, tester.getSize(plan));
    final corridors = [
      for (final record in canvas.invocations)
        if (record.invocation case final call
            when call.memberName == #drawRect &&
                (call.positionalArguments[1] as Paint).color.toARGB32() ==
                    0xFFFFFFFF)
          call.positionalArguments[0] as Rect,
    ];
    bool corridorsVisible() {
      final box = tester.renderObject<RenderBox>(plan);
      final transform = box.getTransformTo(null);
      return corridors.any(
        (rect) => MatrixUtils.transformRect(transform, rect).overlaps(viewport),
      );
    }

    final start = Offset(viewport.center.dx, viewport.bottom - 80);
    final beforePan = tester.getTopLeft(plan).dy;
    await tester.dragFrom(start, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(plan).dy, lessThan(beforePan));
    expect(corridorsVisible(), isTrue);

    for (final control in ['Zoom in', 'Zoom out']) {
      await tester.tap(find.byTooltip(control));
      await tester.pumpAndSettle();
      expect(corridorsVisible(), isTrue);
    }
  });

  testWidgets('rounded corners reject outside taps and accept visible paint', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _Harness().pump(tester);
    await tester.tap(find.byTooltip('Full-screen map'));
    await tester.pumpAndSettle();

    final viewer = find.byType(InteractiveViewer);
    final door = find.byKey(const ValueKey('door-120'));
    final viewport = tester.getRect(viewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    const pin = Offset(251.87, 137.68);
    for (final (corner, inward, pinOffset) in [
      (viewport.topLeft, const Offset(1, 1), const Offset(12, 12)),
      (viewport.topRight, const Offset(-1, 1), const Offset(-2, 30)),
      (viewport.bottomLeft, const Offset(1, -1), const Offset(30, -2)),
      (viewport.bottomRight, const Offset(-1, -1), const Offset(-12, -12)),
      (viewport.topLeft, const Offset(1, 1), const Offset(2, 30)),
    ]) {
      final at = corner + pinOffset;
      final transform = controller.value.clone();
      final delta =
          at - viewport.topLeft - MatrixUtils.transformPoint(transform, pin);
      transform.setEntry(0, 3, transform.entry(0, 3) + delta.dx);
      transform.setEntry(1, 3, transform.entry(1, 3) + delta.dy);
      controller.value = transform;
      await tester.pumpAndSettle();

      final node = tester.getSemantics(door);
      final box = tester.renderObject<RenderBox>(door);
      final outside = corner + inward * 2;
      expect(node.rect.contains(box.globalToLocal(at)), isTrue);
      await tester.tapAt(outside);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(door), isSemantics(isSelected: false));
    }

    controller.value = Matrix4.identity()
      ..translateByDouble(1 - pin.dx * 3.5, 13 - pin.dy * 3.5, 0, 1)
      ..scaleByDouble(3.5, 3.5, 3.5, 1);
    await tester.pumpAndSettle();
    await tester.tapAt(viewport.topLeft + const Offset(6, 8));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(door), isSemantics(isSelected: true));
  });

  testWidgets('partially visible doors keep their own accessibility action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _Harness().pump(tester);
    await tester.tap(find.byTooltip('Full-screen map'));
    await tester.pumpAndSettle();

    final viewer = find.byType(InteractiveViewer);
    final viewport = tester.getRect(viewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    for (final (room, neighbor, pin, offscreen, inset) in [
      ('120', '119', const Offset(251.87, 137.68), 2.0, 1.0),
      ('132', '128', const Offset(552.36, 136.43), 3.6, .1),
    ]) {
      final transform = controller.value.clone();
      final delta =
          Offset(-offscreen, viewport.height / 2) -
          MatrixUtils.transformPoint(transform, pin);
      transform.setEntry(0, 3, transform.entry(0, 3) + delta.dx);
      transform.setEntry(1, 3, transform.entry(1, 3) + delta.dy);
      controller.value = transform;
      await tester.pumpAndSettle();

      final door = find.byKey(ValueKey('door-$room'));
      final neighborDoor = find.byKey(ValueKey('door-$neighbor'));
      final node = tester.getSemantics(door);
      final box = tester.renderObject<RenderBox>(door);
      final visiblePaint = Offset(viewport.left + inset, viewport.center.dy);
      expect(node.rect.contains(box.globalToLocal(visiblePaint)), isTrue);
      expect(
        tester.getRect(door).overlaps(tester.getRect(neighborDoor)),
        isFalse,
      );

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(door), isSemantics(isSelected: true));
    }
  });

  testWidgets('pending notice scrolls without collapsing the full-screen map', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _Harness().pump(tester);
    await tester.tap(find.text('Floor 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-screen map'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(320, 240);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();

    final viewer = find.byType(InteractiveViewer);
    final notice = find.ancestor(
      of: find.textContaining('Corridors are traced from the building scan.'),
      matching: find.byType(Scrollable),
    );
    final viewportHeight = tester.getSize(viewer).height;
    expect(viewportHeight, greaterThan(0));
    expect(viewportHeight, greaterThanOrEqualTo(tester.getSize(notice).height));
    final position = tester.state<ScrollableState>(notice).position;
    await tester.drag(notice, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(tester.getSize(viewer).height, viewportHeight);
  });

  testWidgets('short body leaves the map controls reachable at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 320);
    tester.view.padding = const FakeViewPadding(bottom: 21);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _Harness().pump(tester);

    final expand = find.byTooltip('Full-screen map');
    final roomList = find.byType(Scrollable).first;
    expect(tester.getSize(roomList).height, greaterThan(0));
    await tester.scrollUntilVisible(expand, 35, scrollable: roomList);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit full-screen map'), findsOneWidget);
  });

  testWidgets('map and room-list headings fit large text on a narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _Harness().pump(tester);

    final toolbar = tester.getRect(find.byType(NavigationToolbar));
    for (final text in ['Choose a room', 'Vivian Engineering Center · VEC']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.textScaler.scale(13), 26);
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: text.length - 1, extentOffset: text.length),
        ),
        isNotEmpty,
      );
      final lines = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(
          paragraph.localToGlobal(line.toRect().topLeft).dy,
          greaterThanOrEqualTo(toolbar.top),
        );
        expect(
          paragraph.localToGlobal(line.toRect().bottomRight).dy,
          lessThanOrEqualTo(toolbar.bottom),
        );
      }
    }

    final list = find.byType(Scrollable).first;
    for (final heading in ['Door position verified', 'Not placed on the map']) {
      await tester.scrollUntilVisible(
        find.text(heading),
        160,
        scrollable: list,
      );
    }
  });

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
      await tester.tap(find.text('Verify with AR'));
      await tester.pump();
      expect(find.text('Opening AR for VEC 119…'), findsOneWidget);

      if (selection == 'floor') {
        await tester.tap(find.text('Floor 2'));
      } else if (selection == 'room chip') {
        final chip = find.text('120');
        await tester.scrollUntilVisible(
          chip,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(chip);
      } else {
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('door-120'))),
        );
      }
      await tester.pump();
      expect(find.text('Room 119'), findsNothing);
      expect(find.text('Opening AR for VEC 119…'), findsNothing);
      expect(
        find.text(selection == 'floor' ? 'Pick a room' : 'Room 120'),
        findsOneWidget,
      );
      // The stale lookup must not keep the new room's button busy.
      expect(
        find.text('Verify with AR'),
        selection == 'floor' ? findsNothing : findsOneWidget,
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
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('door-120'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Room 120'), findsOneWidget);
      expect(
        find.text('This door position is verified in the building scan.'),
        findsOneWidget,
      );
      await harness.tapFloorPlanAr(tester);
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
