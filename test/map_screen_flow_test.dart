import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/elbee_gateway.dart';
import 'package:navipet/data/elbee_reply.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/location_service.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/outdoor_ar_contract.dart';
import 'package:navipet/screens/map_screen.dart';
import 'package:navipet/widgets/ar_mode_icon.dart';
import 'package:navipet/widgets/elbee_sheet.dart';
import 'package:navipet/widgets/place_preview_sheet.dart';
import 'package:navipet/widgets/route_preview_sheet.dart';
import 'package:navipet/widgets/search_bar_field.dart';
import 'package:navipet/widgets/search_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The task-15 brief pointed this at 'navigation_flow_controller_test.dart',
// but that file itself imports these fakes from here as `harness` — a test
// file does not re-export its own imports, so `harness.build`/`harness.horn`
// would not exist through that path, and importing a test file from a test
// file also violates the "no test file imports another test file" rule the
// task brief itself lists under GLOBAL CONSTRAINTS. Pointing straight at the
// shared fakes fixes both problems.
import 'support/flow_fakes.dart' as harness;

final arrivalPlace = CampusPlace(
  id: harness.horn.id,
  type: harness.horn.type,
  title: harness.horn.title,
  subtitle: harness.horn.subtitle,
  source: 'cache',
  buildingCode: 'VEC',
  floorNumber: '1',
  outdoorDestination: harness.hornCoordinate,
  footprint: validFootprint({
    'type': 'Polygon',
    'coordinates': [
      [
        [-118.115, 33.7827],
        [-118.114, 33.7827],
        [-118.114, 33.7834],
        [-118.115, 33.7834],
        [-118.115, 33.7827],
      ],
    ],
  }),
);

Widget host(NavigationFlowController controller, {ElbeeGateway? elbee}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider.value(value: controller),
        if (elbee != null) Provider<ElbeeGateway>.value(value: elbee),
      ],
      child: MaterialApp(home: MapScreen(controller: controller)),
    );

class _Elbee implements ElbeeGateway {
  @override
  Future<ElbeeReply> ask(
    String question, {
    required bool scheduleConsent,
  }) async => const ElbeeReply(
    status: ElbeeStatus.ok,
    cards: [ElbeeCard(title: 'Place', placeId: 'external-place')],
  );
}

/// An active walk on a build that opted in to outdoor AR.
Future<(NavigationFlowController, List<OutdoorArRequest>)> pumpOutdoorAr(
  WidgetTester tester, {
  IndoorArResult result = const IndoorArResult(
    status: IndoorArStatus.cancelled,
    localizationQueries: 0,
    durationMs: 1,
  ),
  bool camera = true,
}) async {
  final controller = harness.build();
  final requests = <OutdoorArRequest>[];
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: MaterialApp(
        home: MapScreen(
          controller: controller,
          outdoorArEnabled: true,
          requestCamera: () async => camera,
          launchOutdoorAr: (request) async {
            requests.add(request);
            return result;
          },
        ),
      ),
    ),
  );
  await controller.selectPlace(arrivalPlace);
  await controller.requestDirections();
  await controller.calculateRoute(continueWithUncertain: true);
  await controller.startRoute(continueWithUncertain: true);
  await tester.pump();
  await tester.tap(find.byTooltip('Outdoor AR'));
  await tester.pumpAndSettle();
  return (controller, requests);
}

void main() {
  testWidgets('outdoor AR launches after consent and keeps the route', (
    tester,
  ) async {
    final (controller, requests) = await pumpOutdoorAr(tester);
    final active = controller.state as FlowActiveNavigation;
    expect(find.textContaining('Google will process sensor data'), findsOne);
    expect(find.text('Learn more'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();

    expect(requests.single.toJson(), {
      'schemaVersion': 2,
      'mode': 'outdoor',
      'destination': {
        'name': 'Horn Center',
        'latitude': active.destination.routingCoordinate.latitude,
        'longitude': active.destination.routingCoordinate.longitude,
      },
      'dataUseAccepted': true,
    });
    expect(controller.state, same(active));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('navipet-map')), findsOneWidget);
  });

  testWidgets('outdoor AR does not launch without consent or camera', (
    tester,
  ) async {
    final (controller, requests) = await pumpOutdoorAr(tester, camera: false);
    final active = controller.state;

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byTooltip('Outdoor AR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('needs camera access'), findsOneWidget);

    expect(requests, isEmpty);
    expect(controller.state, same(active));
  });

  for (final (name, result, text) in [
    (
      'no Unity library',
      const IndoorArResult.unavailable(),
      'Outdoor AR guidance is not available yet.',
    ),
    (
      'an indoor-only Unity library',
      const IndoorArResult(
        status: IndoorArStatus.error,
        localizationQueries: 0,
        durationMs: 1,
        errorCode: 'BAD_REQUEST',
      ),
      'Outdoor AR guidance is not available yet.',
    ),
    (
      'a failed session',
      const IndoorArResult(
        status: IndoorArStatus.localizationFailed,
        localizationQueries: 0,
        durationMs: 1,
      ),
      'Outdoor AR could not start.',
    ),
  ]) {
    testWidgets('outdoor AR falls back to the map with $name', (tester) async {
      final (controller, requests) = await pumpOutdoorAr(
        tester,
        result: result,
      );
      final active = controller.state;
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(find.text('Outdoor AR unavailable'), findsOneWidget);
      expect(find.textContaining(text), findsOneWidget);
      await tester.tap(find.text('Return to map'));
      await tester.pumpAndSettle();
      expect(controller.state, same(active));
      expect(active, isA<FlowActiveNavigation>());
    });
  }

  testWidgets('outdoor AR explains availability and preserves active route', (
    tester,
  ) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));
    await controller.selectPlace(arrivalPlace);
    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await controller.startRoute(continueWithUncertain: true);
    await tester.pump();

    final active = controller.state;
    expect(active, isA<FlowActiveNavigation>());
    expect(find.byTooltip('Outdoor AR unavailable'), findsOneWidget);
    expect(find.text('AR'), findsNothing);
    expect(find.byKey(const ValueKey('navipet-map')), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Outdoor AR unavailable')),
      isSemantics(isButton: true, hasTapAction: true),
    );

    await tester.tap(find.byTooltip('Map type'));
    await tester.pumpAndSettle();
    expect(find.text('Map type'), findsOneWidget);
    expect(find.byTooltip('Outdoor AR unavailable'), findsOneWidget);
    await tester.tap(find.text('Standard').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Outdoor AR unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Outdoor AR guidance is not available yet. Your walking route stays active on the map.',
      ),
      findsOneWidget,
    );
    expect(controller.state, same(active));

    await tester.tap(find.text('Return to map'));
    await tester.pumpAndSettle();
    expect(controller.state, same(active));
    expect(
      (controller.state as FlowActiveNavigation).destination.name,
      'Horn Center',
    );
    expect(find.byKey(const ValueKey('navipet-map')), findsOneWidget);
    expect(find.byTooltip('Outdoor AR unavailable'), findsOneWidget);
  });

  testWidgets('outdoor AR control stays reachable with safe-area insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 40);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final controller = harness.build();
    await tester.pumpWidget(host(controller));
    await controller.selectPlace(arrivalPlace);
    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await controller.startRoute(continueWithUncertain: true);
    await tester.pump();

    final button = tester.getRect(find.byTooltip('Outdoor AR unavailable'));
    expect(button.width, 112);
    expect(button.height, 56);
    expect(button.right, lessThanOrEqualTo(400 - 16));
    expect(button.top, greaterThan(48));
    expect(button.bottom, lessThan(1600 / 2 - 40));
    expect(tester.takeException(), isNull);
  });

  Future<void> driveToArrival(NavigationFlowController controller) async {
    await controller.selectPlace(arrivalPlace);
    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await controller.startRoute(continueWithUncertain: true);
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );
  }

  final arButton = find.byType(ArModeIcon);
  // Lets the controller's stale-fix timer fire so none is pending at teardown.
  const staleFix = Duration(seconds: 11);

  testWidgets('poor indoor fix offers Scan AR and opens the selected room', (
    tester,
  ) async {
    final controller = harness.build()..openSearch();
    final room = CampusPlace(
      id: 'vec119',
      type: CampusDestinationType.room,
      buildingCode: 'VEC',
      title: 'VEC 119',
      subtitle: 'Test',
      source: 'cache',
      outdoorDestination: harness.hornCoordinate,
      footprint: arrivalPlace.footprint,
      roomNumber: '119',
      floorNumber: '1',
      indoorDestinationId: 'room119',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider.value(value: controller),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => MapScreen(controller: controller),
              ),
              GoRoute(
                path: '/ar',
                builder: (context, state) => Text(
                  'destination ${state.uri.queryParameters['destination']}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await controller.selectPlace(room);
    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await controller.startRoute(continueWithUncertain: true);
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 35,
      timestamp: DateTime.now(),
    );
    await tester.pump();
    expect(find.text('Scan AR'), findsNothing);
    expect(find.byTooltip('Scan AR'), findsOneWidget);
    await tester.tap(find.byTooltip('Scan AR'));
    await tester.pumpAndSettle();
    expect(find.text('destination vec119'), findsOneWidget);
    await tester.pump(staleFix);
  });

  testWidgets('arrival shows no message and returns to the map', (
    tester,
  ) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));
    await driveToArrival(controller);
    await tester.pump();
    expect(find.text('You’ve arrived!'), findsNothing);
    expect(find.text(harness.horn.title), findsNothing);
    expect(find.textContaining('Distance traveled:'), findsNothing);
    await tester.tap(find.text('Return to map'));
    await tester.pump();
    expect(find.byType(SearchBarField), findsOneWidget);
    expect(arButton, findsNothing);
  });

  for (final place in [
    const CampusPlace(
      id: 'external-place',
      type: CampusDestinationType.building,
      title: 'External campus result',
      subtitle: 'Outside CSULB',
      source: 'csulb',
      external: true,
      outdoorDestination: harness.hornCoordinate,
    ),
    const CampusPlace(
      id: 'external-place',
      type: CampusDestinationType.building,
      title: 'Mapbox result',
      subtitle: 'Mapbox only',
      source: 'mapbox',
      outdoorDestination: harness.hornCoordinate,
    ),
  ]) {
    testWidgets('Elbee rejects ${place.title} before selecting it', (
      tester,
    ) async {
      final search = harness.FakeSearchGateway()..results = [place];
      final controller = harness.build(search: search);
      await tester.pumpWidget(host(controller, elbee: _Elbee()));
      await tester.tap(find.text('Ask Elbee'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Find this place');
      await tester.tap(
        find.descendant(
          of: find.byType(ElbeeSheet),
          matching: find.text('Ask Elbee'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Place'));
      await tester.pumpAndSettle();

      expect(
        find.text('Elbee can only open verified CSULB campus places.'),
        findsOneWidget,
      );
      expect(controller.destination, isNull);
    });
  }

  testWidgets('indoor AR button shows only on arrival, above side buttons', (
    tester,
  ) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));
    await tester.pump();
    expect(arButton, findsNothing);

    controller.openSearch();
    await controller.selectPlace(arrivalPlace);
    await tester.pump();
    expect(arButton, findsNothing);

    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await tester.pump();
    expect(arButton, findsNothing);

    await controller.startRoute(continueWithUncertain: true);
    await tester.pump();
    expect(arButton, findsOneWidget);
    expect(find.byTooltip('Outdoor AR unavailable'), findsOneWidget);

    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );
    await controller.onLiveLocation(
      harness.hornCoordinate,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );
    await tester.pump();
    expect(arButton, findsOneWidget);
    expect(find.byTooltip('Outdoor AR unavailable'), findsNothing);
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('AR mode'), findsNothing);
    expect(find.bySemanticsLabel('AR mode'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('AR mode')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getBottomLeft(arButton).dy,
      lessThan(tester.getTopLeft(find.byIcon(Icons.layers_outlined)).dy),
    );
    await tester.pump(staleFix);
  });

  testWidgets('the AR button passes destination to /ar and survives return', (
    tester,
  ) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider.value(value: controller),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => MapScreen(controller: controller),
              ),
              GoRoute(
                path: '/ar',
                builder: (context, state) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'ar screen ${state.uri.queryParameters['destination']}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await driveToArrival(controller);
    await tester.pump();

    await tester.tap(arButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ar screen ${harness.horn.id}'), findsOneWidget);

    await tester.tap(find.text('ar screen ${harness.horn.id}'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(arButton, findsOneWidget);
    await tester.pump(staleFix);
  });

  testWidgets('walks search to place preview to route preview', (tester) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));

    controller.openSearch();
    await tester.pump();
    expect(find.byType(SearchOverlay), findsOneWidget);

    await controller.selectPlace(arrivalPlace);
    await tester.pump();
    expect(find.byType(PlacePreviewSheet), findsOneWidget);

    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await tester.pump();
    expect(find.byType(RoutePreviewSheet), findsOneWidget);
  });

  testWidgets('back unwinds one state at a time', (tester) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));

    controller.openSearch();
    await controller.selectPlace(arrivalPlace);
    await controller.requestDirections();
    await controller.calculateRoute(continueWithUncertain: true);
    await tester.pump();

    controller.back();
    await tester.pump();
    expect(find.byType(PlacePreviewSheet), findsOneWidget);

    controller.back();
    await tester.pump();
    expect(find.byType(SearchOverlay), findsOneWidget);

    controller.back();
    await tester.pump();
    expect(find.byType(SearchOverlay), findsNothing);
    expect(find.byType(PlacePreviewSheet), findsNothing);
  });

  testWidgets(
    'renders the expanded step list without an unbounded-height layout '
    'error',
    (tester) async {
      // Regression test for the layout hazard the task brief flagged:
      // RoutePreviewSheet's expanded step list is a Flexible(ListView) inside
      // a mainAxisSize.min Column, which only works if its container gives it
      // a bounded height. A Positioned with only `bottom` set (no `top`) —
      // the brief's own suggested container — gives the Stack's positioned
      // child an *unbounded* height, which throws at layout once the
      // Flexible child is present. MapScreen must instead give this sheet a
      // bounded height (see the FlowRouteSteps branch in map_screen.dart).
      final controller = harness.build();
      await tester.pumpWidget(host(controller));

      controller.openSearch();
      await controller.selectPlace(arrivalPlace);
      await controller.requestDirections();
      await controller.calculateRoute(continueWithUncertain: true);
      controller.showSteps();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(RoutePreviewSheet), findsOneWidget);
      expect(find.text('Walk north'), findsOneWidget);
    },
  );

  testWidgets(
    'drives search to route preview through real taps, the way the app is '
    'actually used',
    (tester) async {
      // The other tests above call controller methods directly and then
      // pump — useful for exercising the state machine, but it never proves
      // MapScreen reacts to the UI the way a real user's taps would.  This
      // one goes through the widgets themselves, and only uses
      // tester.pump(duration) where a real timer (the search debounce) is
      // genuinely involved — not as a substitute for the frames the real
      // app would draw in between.
      final controller = harness.build();
      await tester.pumpWidget(host(controller));

      await tester.tap(find.byType(SearchBarField));
      await tester.pump();
      expect(find.byType(SearchOverlay), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'horn');
      await tester.pump(); // the typing frame: no results yet
      expect(find.text('Horn Center'), findsNothing);
      await tester.pump(const Duration(milliseconds: 20)); // debounce fires
      await tester.pump(); // the debounced result's own frame

      expect(find.text('Horn Center'), findsOneWidget);
      await tester.tap(find.text('Horn Center'));
      await tester.pump();
      expect(find.byType(PlacePreviewSheet), findsOneWidget);

      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(find.text('Start route'), findsOneWidget);

      await tester.tap(find.text('Start route'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Confirm your location'), findsNothing);
      expect(find.text("You're already here"), findsNothing);
      expect(find.byType(RoutePreviewSheet), findsOneWidget);
    },
  );

  testWidgets(
    'unmounting MapScreen detaches the map, so a route calculation that '
    'lands after navigating away does not call into the disposed map '
    'surface',
    (tester) async {
      // Regression test for the review finding: NaviBottomNav's context.go
      // to /checklist or /pet disposes MapScreen while this app-scoped flow
      // keeps calculating in the background. Before detachMap() existed,
      // the reply would call into a MapboxNaviMapController wrapping an
      // already-torn-down MapboxMap.
      final map = harness.RecordingMap();
      final routes = harness.FakeRouteGateway()..block();
      final controller = harness.build(map: map, routes: routes);
      await tester.pumpWidget(host(controller));

      controller.openSearch();
      await controller.selectPlace(arrivalPlace);
      await controller.requestDirections();
      // selectPlace() already drew the place marker — clear that so the
      // assertion below only checks for the calculation's own reply.
      map.calls.clear();
      final pending = controller.calculateRoute(continueWithUncertain: true);

      // Simulate navigating away before the calculation resolves — the
      // same MapScreen.dispose() path NaviBottomNav's context.go triggers.
      await tester.pumpWidget(const SizedBox.shrink());

      routes.unblock();
      await pending;

      // The reply landed on a flow with no attached map: it must not reach
      // the RecordingMap this now-disposed MapScreen was using.
      expect(map.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("hands the persisted last-known location to the flow's location "
      'service, so a momentary GPS dropout still has an approximate origin '
      'to fall back to', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_location_latitude': 33.7838,
      'last_location_longitude': -118.1141,
    });
    final location = harness.FakeLocationService();
    final controller = harness.build(location: location);
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    expect(location.primedLastKnown, isNotNull);
    expect(location.primedLastKnown!.latitude, 33.7838);
    expect(location.primedLastKnown!.longitude, -118.1141);
  });

  testWidgets('app resume rechecks location and renders the flow notice', (
    tester,
  ) async {
    final location = harness.FakeLocationService()
      ..reading = const LocationReading(
        availability: LocationAvailability.permissionDenied,
      );
    final controller = harness.build(location: location);
    await tester.pumpWidget(host(controller));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Turn on location to route from here.'), findsOneWidget);
  });
}
