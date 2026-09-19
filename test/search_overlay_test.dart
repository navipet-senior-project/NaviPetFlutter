import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/widgets/search_overlay.dart';

import 'support/flow_fakes.dart' as harness;

Widget host(NavigationFlowController controller) => MaterialApp(
  home: Scaffold(body: SearchOverlay(controller: controller)),
);

/// Fails the first `autocomplete` call with [exception], then serves
/// [harness.FakeSearchGateway.results] normally — for exercising a retry
/// that actually recovers, not just a permanently-broken search.
class _FlakySearchGateway extends harness.FakeSearchGateway {
  _FlakySearchGateway(this.exception);

  final CampusSearchException exception;
  bool _thrown = false;

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async {
    if (!_thrown) {
      _thrown = true;
      throw exception;
    }
    return super.autocomplete(query, proximity: proximity, limit: limit);
  }
}

/// Always fails `autocomplete` with [exception] — for statuses that don't
/// need a recovery path in the test.
class _FailingSearchGateway extends harness.FakeSearchGateway {
  _FailingSearchGateway(this.exception);

  final CampusSearchException exception;

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async => throw exception;
}

void main() {
  testWidgets('autofocuses the field and shows a back button', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.bySemanticsLabel('Close search'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('shows a clear button once text exists', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));

    expect(find.bySemanticsLabel('Clear search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'horn');
    // The CampusSearchController debounce timer (10ms in this harness) must
    // fire and settle before the test ends, or flutter_test's binding
    // invariant check fails with "A Timer is still pending" — see
    // test/search_screen_test.dart for the same pattern.
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('groups results under a type heading', (tester) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextField), 'horn');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Buildings'), findsOneWidget);
    expect(find.text('Horn Center'), findsOneWidget);
  });

  testWidgets('shows the campus-only empty state', (tester) async {
    final search = harness.FakeSearchGateway()..results = const [];
    final controller = harness.build(search: search)..openSearch();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextField), 'vons');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(
      find.text("No campus places match 'vons'. NaviPet searches CSULB only."),
      findsOneWidget,
    );
  });

  testWidgets(
    'rebuilds from the debounced result landing, not from the keystroke '
    'frame alone',
    (tester) async {
      // Regression test for the review finding: the overlay used to only
      // setState() from TextField.onChanged, which repaints the *typing*
      // frame but never repaints again once the debounced search actually
      // resolves. A bare pump() right after the keystroke — before the
      // debounce elapses — must NOT show a result: if it did, something
      // upstream (e.g. FakeSearchGateway resolving instantly) would be
      // papering over the missing listener, the same "timing coincidence"
      // the review called out.
      final controller = harness.build()..openSearch();
      await tester.pumpWidget(host(controller));

      await tester.enterText(find.byType(TextField), 'horn');
      await tester.pump();
      expect(find.text('Horn Center'), findsNothing);

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();

      expect(find.text('Buildings'), findsOneWidget);
      expect(find.text('Horn Center'), findsOneWidget);
    },
  );

  testWidgets('shows unauthorized distinctly from a generic api error', (
    tester,
  ) async {
    final search = _FailingSearchGateway(
      const CampusSearchException(
        failure: CampusSearchFailure.unauthorized,
        message: 'Sign in again to search campus.',
      ),
    );
    final controller = harness.build(search: search)..openSearch();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextField), 'horn');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Sign in again to search campus.'), findsOneWidget);
    // Unauthorized has no retry — signing in again happens elsewhere, not
    // by repeating the same request — unlike apiError/offline below.
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('offline shows a retry button that actually recovers', (
    tester,
  ) async {
    final search = _FlakySearchGateway(
      const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Campus search is offline.',
      ),
    )..results = const [harness.horn];
    final controller = harness.build(search: search)..openSearch();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextField), 'horn');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Campus search is offline.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Horn Center'), findsOneWidget);
  });

  testWidgets('shows a populated list of recent searches', (tester) async {
    final recents = harness.FakeRecents()..stored = const [harness.horn];
    final controller = harness.build(recents: recents)..openSearch();
    await tester.pumpWidget(host(controller));
    await tester.pump();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Horn Center'), findsOneWidget);
  });

  testWidgets('tapping a result selects the place', (tester) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextField), 'horn');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    await tester.tap(find.text('Horn Center'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<FlowPlacePreview>());
    expect((controller.state as FlowPlacePreview).place.id, harness.horn.id);
  });

  testWidgets('shows a hint while picking a route origin', (tester) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    controller.openSearch(pickingOrigin: true);
    await tester.pump();

    expect(find.text('Choose a starting point'), findsOneWidget);
  });

  testWidgets('surfaces the pick error for an origin with no map location', (
    tester,
  ) async {
    final controller = harness.build()..openSearch();
    await tester.pumpWidget(host(controller));
    await controller.selectPlace(harness.horn);
    await controller.requestDirections();

    controller.openSearch(pickingOrigin: true);
    await controller.selectPlace(harness.unmapped);
    await tester.pump();

    expect(
      find.text('${harness.unmapped.title} has no location on the map yet.'),
      findsOneWidget,
    );
  });
}
