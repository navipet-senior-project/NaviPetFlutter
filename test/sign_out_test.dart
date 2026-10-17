import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/account_settings_screen.dart';
import 'package:provider/provider.dart';

class _FixedTokenProvider implements AuthTokenProvider {
  @override
  Future<String?> token({bool forceRefresh = false}) async => 'current-token';
}

class _Harness {
  _Harness({int logoutStatus = 204}) {
    final client = MockClient((request) async {
      events.add('logout:${request.headers['authorization']}');
      if (logoutStatus == 204) return http.Response('', 204);
      return http.Response(
        jsonEncode({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'boom'},
        }),
        logoutStatus,
        headers: {'content-type': 'application/json'},
      );
    });
    state = AppState(
      registrationGateway: HttpRegistrationGateway(
        baseUrl: 'https://api.test/',
        client: client,
      ),
      authTokenProvider: _FixedTokenProvider(),
      sessionDiscarder: () async => events.add('discard'),
    );
  }

  final List<String> events = [];
  late final AppState state;
}

void main() {
  group('AppState.signOut', () {
    test(
      'revokes the session with the current token, then discards it',
      () async {
        final harness = _Harness();

        await harness.state.signOut();

        expect(harness.events, ['logout:Bearer current-token', 'discard']);
        expect(harness.state.isBusy, isFalse);
        harness.state.dispose();
      },
    );

    test('still discards the session when the backend call fails', () async {
      final harness = _Harness(logoutStatus: 500);

      await harness.state.signOut();

      expect(harness.events, ['logout:Bearer current-token', 'discard']);
      expect(harness.state.errorMessage, isNull);
      expect(harness.state.isBusy, isFalse);
      harness.state.dispose();
    });
  });

  testWidgets('Sign Out on Profile & Settings calls AppState.signOut', (
    tester,
  ) async {
    final harness = _Harness();
    // The settings cards trip Flutter's debug-only "ink splashes may be
    // invisible" report (existing code); only that report is ignored.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
        'ink splashes may be invisible',
      )) {
        return;
      }
      original?.call(details);
    };
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: harness.state,
          child: const MaterialApp(home: AccountSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(OutlinedButton, 'Sign Out');
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(harness.events, ['logout:Bearer current-token', 'discard']);
    } finally {
      FlutterError.onError = original;
      harness.state.dispose();
    }
  });
}
