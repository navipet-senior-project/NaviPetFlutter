import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_spike_screen.dart';

void main() {
  testWidgets('launches VEC 119 and shows each result', (tester) async {
    final launcher = FakeIndoorArLauncher(
      result: const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 0,
        durationMs: 4200,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: IndoorArSpikeScreen(launcher: launcher)),
    );

    expect(find.text('Request: VEC119, floor 1'), findsOneWidget);

    await tester.tap(find.text('Launch AR'));
    await tester.pumpAndSettle();

    expect(launcher.requests.single.doorKey, 'VEC119');
    expect(find.text('Launches: 1'), findsOneWidget);
    expect(find.text('Status: arrived'), findsOneWidget);
    expect(find.text('Distance: 0.50 m'), findsOneWidget);

    launcher.result = const IndoorArResult(
      status: IndoorArStatus.error,
      localizationQueries: 0,
      durationMs: 800,
      errorCode: 'UNITY_EXITED',
    );
    await tester.tap(find.text('Launch AR'));
    await tester.pumpAndSettle();

    expect(find.text('Launches: 2'), findsOneWidget);
    expect(find.text('Status: error'), findsOneWidget);
    expect(find.text('Error: UNITY_EXITED'), findsOneWidget);
    expect(find.textContaining('Distance'), findsNothing);
  });
}
