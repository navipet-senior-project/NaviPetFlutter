import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/widgets/search_overlay.dart';

import 'support/flow_fakes.dart' as harness;

Widget host(NavigationFlowController controller) => MaterialApp(
  home: Scaffold(body: SearchOverlay(controller: controller)),
);

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
}
