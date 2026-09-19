import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/screens/map_screen.dart';
import 'package:navipet/widgets/place_preview_sheet.dart';
import 'package:navipet/widgets/route_preview_sheet.dart';
import 'package:navipet/widgets/search_bar_field.dart';
import 'package:navipet/widgets/search_overlay.dart';
import 'package:provider/provider.dart';

// The task-15 brief pointed this at 'navigation_flow_controller_test.dart',
// but that file itself imports these fakes from here as `harness` — a test
// file does not re-export its own imports, so `harness.build`/`harness.horn`
// would not exist through that path, and importing a test file from a test
// file also violates the "no test file imports another test file" rule the
// task brief itself lists under GLOBAL CONSTRAINTS. Pointing straight at the
// shared fakes fixes both problems.
import 'support/flow_fakes.dart' as harness;

Widget host(NavigationFlowController controller) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppState()),
    ChangeNotifierProvider.value(value: controller),
  ],
  child: MaterialApp(home: MapScreen(controller: controller)),
);

void main() {
  testWidgets('walks search to place preview to route preview', (tester) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));

    controller.openSearch();
    await tester.pump();
    expect(find.byType(SearchOverlay), findsOneWidget);

    await controller.selectPlace(harness.horn);
    await tester.pump();
    expect(find.byType(PlacePreviewSheet), findsOneWidget);

    await controller.requestDirections();
    await controller.calculateRoute();
    await tester.pump();
    expect(find.byType(RoutePreviewSheet), findsOneWidget);
  });

  testWidgets('back unwinds one state at a time', (tester) async {
    final controller = harness.build();
    await tester.pumpWidget(host(controller));

    controller.openSearch();
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();
    await controller.calculateRoute();
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
      await controller.selectPlace(harness.horn);
      await controller.requestDirections();
      await controller.calculateRoute();
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
      expect(find.byType(RoutePreviewSheet), findsOneWidget);
    },
  );
}
