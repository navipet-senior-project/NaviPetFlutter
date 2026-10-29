import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/router/app_router.dart';
import 'package:navipet/screens/account_settings_screen.dart';
import 'package:navipet/screens/change_email_screen.dart';
import 'package:navipet/screens/indoor_ar_launch_screen.dart';
import 'package:navipet/screens/indoor_ar_spike_screen.dart';
import 'package:navipet/screens/verify_email_screen.dart';

import 'email_change_test_support.dart';
import 'package:navipet/screens/reset_password_screen.dart';
import 'package:navipet/screens/sign_in_screen.dart';

class _RouterAppState extends AppState {
  _RouterAppState({
    required this.authenticated,
    required this.passwordRecovery,
    this.recoverySession = false,
  });

  final bool authenticated;
  final bool passwordRecovery;
  final bool recoverySession;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get isPasswordRecovery => passwordRecovery;

  @override
  bool get hasPasswordRecoverySession => recoverySession;

  @override
  bool get hasPendingPasswordRecovery => recoverySession;
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

  testWidgets(
    'allows a verified recovery session to open Reset Password while signed out',
    (tester) async {
      final appState = _RouterAppState(
        authenticated: false,
        passwordRecovery: false,
        recoverySession: true,
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
      router.go('/reset-password');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/reset-password');
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    },
  );

  testWidgets('opens the debug indoor AR spike route when signed in', (
    tester,
  ) async {
    final appState = _RouterAppState(
      authenticated: true,
      passwordRecovery: false,
    );
    final router = createAppRouter(
      appState,
      initialLocation: '/dev/indoor-ar-spike',
    );
    addTearDown(router.dispose);
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndoorArSpikeScreen), findsOneWidget);
  });

  testWidgets('/ar builds the indoor AR launch screen', (tester) async {
    final appState = _RouterAppState(
      authenticated: true,
      passwordRecovery: false,
    );
    final router = createAppRouter(appState, initialLocation: '/ar');
    addTearDown(router.dispose);
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndoorArLaunchScreen), findsOneWidget);
    expect(
      find.text("Indoor AR isn't available for this room"),
      findsOneWidget,
    );
  });

  testWidgets('redirects a guest from the indoor AR spike route to sign in', (
    tester,
  ) async {
    final appState = _RouterAppState(
      authenticated: false,
      passwordRecovery: false,
    );
    final router = createAppRouter(
      appState,
      initialLocation: '/dev/indoor-ar-spike',
    );
    addTearDown(router.dispose);
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndoorArSpikeScreen), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
  group('email change routes', () {
    Future<void> open(
      WidgetTester tester,
      EmailChangeHarness harness,
      String location,
    ) async {
      final router = createAppRouter(harness.state, initialLocation: location);
      addTearDown(router.dispose);
      await ignoringInkSplashReports(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: harness.state,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a guest opening /account/email lands on Account', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester, anonymous: true);
      addTearDown(harness.state.dispose);

      await open(tester, harness, '/account/email');

      expect(find.byType(ChangeEmailScreen), findsNothing);
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
    });

    testWidgets('a guest opening the code route lands on Account', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester, anonymous: true);
      addTearDown(harness.state.dispose);

      await open(
        tester,
        harness,
        '/account/email/verify?email=new%40example.com',
      );

      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
    });

    testWidgets('a signed-in user reaches the change-email screen with the '
        'password step', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);

      await open(
        tester,
        harness,
        '/account/email?email=new%40example.com&reauth=1',
      );

      expect(find.byType(ChangeEmailScreen), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('change-email-password-field')),
        findsOneWidget,
      );
    });

    testWidgets('a signed-in user reaches the code screen for the new email', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);

      await open(
        tester,
        harness,
        '/account/email/verify?email=new%40example.com',
      );

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Confirm your new email'), findsOneWidget);
      expect(find.textContaining('new@example.com'), findsOneWidget);
    });
  });
}
