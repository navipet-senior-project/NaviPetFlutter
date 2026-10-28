import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/indoor_ar_contract.dart';
import 'package:navipet/data/indoor_ar_launcher.dart';
import 'package:navipet/screens/indoor_ar_spike_screen.dart';

Future<List<String>> _pump(
  WidgetTester tester,
  FakeIndoorArLauncher launcher,
) async {
  final opened = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => IndoorArSpikeScreen(launcher: launcher),
      ),
      GoRoute(
        path: '/ar',
        builder: (_, state) {
          opened.add(state.uri.queryParameters['destinationId']!);
          return const Text('ar');
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('lists the 17 VEC floor 1–2 doors', () {
    expect(IndoorArSpikeScreen.doors, hasLength(17));
    expect(IndoorArSpikeScreen.doors.first, (
      'VEC119',
      '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f',
    ));
  });

  testWidgets('tapping a room opens AR for its destination', (tester) async {
    final opened = await _pump(tester, FakeIndoorArLauncher());
    await tester.tap(find.text('VEC119'));
    await tester.pumpAndSettle();
    expect(opened, ['3c011e42-ad7d-4f6c-81d5-e7b23e977d1f']);
  });

  testWidgets('shows a result recovered after a restart', (tester) async {
    final launcher = FakeIndoorArLauncher()
      ..pending = const IndoorArResult(
        status: IndoorArStatus.arrived,
        checkDistanceM: 0.5,
        localizationQueries: 2,
        durationMs: 4200,
      );
    await _pump(tester, launcher);
    expect(find.text('Recovered result: arrived, 0.50 m'), findsOneWidget);
  });
}
