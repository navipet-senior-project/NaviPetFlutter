import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/email_change.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/verify_email_screen.dart';

import 'email_change_test_support.dart';

class _FakeRegistrationGateway implements RegistrationGateway {
  String? capturedEmail;
  String? capturedCode;
  RegistrationException? error;
  int recoveryRequestCount = 0;

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) async => const RegistrationVerificationSuccess(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) => throw UnimplementedError();

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    capturedEmail = email;
    capturedCode = code;
    if (error != null) throw error!;
    return const RegistrationVerificationSuccess(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async {
    recoveryRequestCount++;
    if (error != null) throw error!;
    return const PasswordResetRequestSuccess(
      message: 'Verification code sent. Check your inbox.',
    );
  }

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) => verifyRegistrationCode(email: email, code: code);

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) async {}
  @override
  Future<void> requestEmailChange({
    required String accessToken,
    required String newEmail,
  }) => throw UnimplementedError();

  @override
  Future<EmailChangeVerificationSuccess> verifyEmailChangeCode({
    required String newEmail,
    required String code,
  }) => throw UnimplementedError();
}

Widget _harness(AppState appState) {
  final router = GoRouter(
    initialLocation: '/verify-email?email=person%40example.com',
    routes: [
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('Register screen')),
      ),
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: Text('Map screen')),
      ),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  for (var index = 0; index < code.length; index++) {
    await tester.enterText(
      find.byKey(ValueKey('verification-code-$index')),
      code[index],
    );
  }
  await tester.pump();
}

Widget _emailChangeApp(AppState appState) {
  final router = GoRouter(
    initialLocation: '/account/email/verify?email=new%40example.com',
    routes: [
      GoRoute(
        path: '/account/email/verify',
        builder: (_, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: VerificationPurpose.emailChange,
        ),
      ),
      GoRoute(
        path: '/account/email',
        builder: (_, state) => Scaffold(
          body: Text(
            'Change email ${state.uri.queryParameters['email']} '
            'reauth=${state.uri.queryParameters['reauth']}',
          ),
        ),
      ),
      GoRoute(
        path: '/account',
        builder: (_, _) => const Scaffold(body: Text('Account screen')),
      ),
      GoRoute(
        path: '/signin',
        builder: (_, _) => const Scaffold(body: Text('Sign in screen')),
      ),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('submits six digits and continues to the map', (tester) async {
    final gateway = _FakeRegistrationGateway();
    final appState = AppState(
      registrationGateway: gateway,
      verificationSessionHandler: (_) async {},
    );
    addTearDown(appState.dispose);
    await tester.pumpWidget(_harness(appState));

    expect(find.textContaining('person@example.com'), findsOneWidget);
    expect(find.text('Code expires in 3:00'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verify and continue'),
    );
    expect(button.onPressed, isNull);

    await _enterCode(tester, '123456');
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Verify and continue'),
    );
    await tester.pumpAndSettle();

    expect(gateway.capturedEmail, 'person@example.com');
    expect(gateway.capturedCode, '123456');
    expect(find.text('Map screen'), findsOneWidget);
  });

  testWidgets('expires after three minutes and does not submit the code', (
    tester,
  ) async {
    final gateway = _FakeRegistrationGateway();
    final appState = AppState(
      registrationGateway: gateway,
      verificationSessionHandler: (_) async {},
    );
    addTearDown(appState.dispose);
    await tester.pumpWidget(_harness(appState));
    await _enterCode(tester, '123456');

    await tester.pump(const Duration(minutes: 3));
    await tester.pump();

    expect(find.text('Code expired — request a new one'), findsOneWidget);
    expect(
      find.text('This verification code has expired. Request a new code.'),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verify and continue'),
    );
    expect(button.onPressed, isNull);
    expect(gateway.capturedCode, isNull);
  });

  testWidgets('shows the backend message for an invalid code', (tester) async {
    final gateway = _FakeRegistrationGateway()
      ..error = const RegistrationException(
        message: 'The verification code is invalid or expired.',
        statusCode: 401,
        code: 'INVALID_OTP',
      );
    final appState = AppState(
      registrationGateway: gateway,
      verificationSessionHandler: (_) async {},
    );
    addTearDown(appState.dispose);
    await tester.pumpWidget(_harness(appState));

    await _enterCode(tester, '654321');
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Verify and continue'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'That code is invalid or expired. Request a new code and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Map screen'), findsNothing);
  });
  group('email change', () {
    testWidgets('shows a 60-minute code and holds Resend for 60 seconds', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your new email'), findsOneWidget);
      expect(find.textContaining('new@example.com'), findsOneWidget);
      expect(find.text('Code expires in 60:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('email-change-hint')), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Resend code in 60s'),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(find.text('Code expires in 59:00'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Resend Code'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('confirms the code, installs the session, and shows the '
        'message on Account', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();

      await _enterCode(tester, '123456');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm new email'),
      );
      await tester.pumpAndSettle();

      expect(harness.gateway.verifications, [
        (newEmail: 'new@example.com', code: '123456'),
      ]);
      expect(harness.installed, hasLength(1));
      expect(find.text('Account screen'), findsOneWidget);
      expect(
        find.text('Email updated. Use this email the next time you sign in.'),
        findsOneWidget,
      );
    });

    testWidgets('sends a recovery-purpose session to Sign In', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.verifyResult = EmailChangeVerificationSuccess(
        tokens: RegistrationVerificationSuccess(
          accessToken: tokenWithPurpose('recovery'),
          refreshToken: 'recovery-refresh',
        ),
        message: 'Email updated. Use this email the next time you sign in.',
      );
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();

      await _enterCode(tester, '123456');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm new email'),
      );
      await tester.pumpAndSettle();

      expect(harness.installed, isEmpty);
      expect(harness.discardCount, 1);
      expect(find.text('Sign in screen'), findsOneWidget);
      expect(find.text(emailChangeSignInNotice), findsOneWidget);
    });

    testWidgets('shows the invalid-code text and stays on the screen', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.verifyError = const RegistrationException(
        message: 'Invalid or expired code.',
        statusCode: 401,
        code: 'INVALID_OTP',
      );
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();

      await _enterCode(tester, '000000');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm new email'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'That code is invalid or expired. Request a new code and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('resends through change-email and restarts the hold', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      await tester.ensureVisible(find.text('Resend Code'));
      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(harness.gateway.requests, [
        (accessToken: 'stale-token', newEmail: 'new@example.com'),
      ]);
      expect(find.text('A new code was sent.'), findsOneWidget);
      expect(find.text('Code expires in 60:00'), findsOneWidget);
      expect(find.text('Resend code in 60s'), findsOneWidget);
    });

    testWidgets('sends a resend REAUTH_REQUIRED to the password step', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.requestErrors.add(reauthRequiredError);
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      await tester.ensureVisible(find.text('Resend Code'));
      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Change email new@example.com reauth=1'),
        findsOneWidget,
      );
    });

    testWidgets('back returns to the change-email screen with the address', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      await tester.pumpWidget(_emailChangeApp(harness.state));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(
        find.text('Change email new@example.com reauth=null'),
        findsOneWidget,
      );
    });
  });
}
