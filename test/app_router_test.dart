import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/router/app_router.dart';
import 'package:navipet/screens/sign_in_screen.dart';

class _RouterAppState extends AppState {
  _RouterAppState({
    required this.authenticated,
    required this.passwordRecovery,
  });

  final bool authenticated;
  final bool passwordRecovery;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get isPasswordRecovery => passwordRecovery;
}

void main() {
  testWidgets(
    'keeps a signed-out recovery state on sign-in without a redirect loop',
    (tester) async {
      final appState = _RouterAppState(
        authenticated: false,
        passwordRecovery: true,
      );
      final router = createAppRouter(appState);
      addTearDown(router.dispose);
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/signin');
      expect(find.byType(SignInScreen), findsOneWidget);
    },
  );
}
