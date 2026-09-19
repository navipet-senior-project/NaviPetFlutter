import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/widgets/search_overlay.dart';

import 'support/flow_fakes.dart' as harness;

void main() {
  testWidgets('search overlay meets tap target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final controller = harness.build()..openSearch();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SearchOverlay(controller: controller)),
      ),
    );
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets('results survive a 2x text scale without overflow', (
    tester,
  ) async {
    final controller = harness.build()..openSearch();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: SearchOverlay(controller: controller)),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'horn');
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
