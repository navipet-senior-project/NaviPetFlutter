import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/email_sent_screen.dart';
import 'package:navipet/screens/forgot_password_screen.dart';
import 'package:navipet/screens/reset_password_screen.dart';
import 'package:navipet/screens/sign_in_screen.dart';
import 'package:navipet/screens/verify_email_screen.dart';

class _FakeAuthGateway implements RegistrationGateway {
  RegistrationException? signInError;
  RegistrationException? recoveryError;
  RegistrationException? verificationError;
  RegistrationException? resetError;
  int recoveryRequestCount = 0;
  int recoveryVerificationCount = 0;
  int resetCount = 0;
  String? resetAccessToken;
  String? newPassword;
  String? confirmPassword;

  static const tokens = RegistrationVerificationSuccess(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    return tokens;
  }

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => const RegistrationSuccess(
    message: 'Verification code sent. Check your inbox.',
    otpRequired: true,
  );

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    if (verificationError != null) throw verificationError!;
    return tokens;
  }

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async {
    recoveryRequestCount++;
    if (recoveryError != null) throw recoveryError!;
    return const PasswordResetRequestSuccess(
      message: 'Verification code sent. Check your inbox.',
    );
  }

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) async {
    recoveryVerificationCount++;
    if (verificationError != null) throw verificationError!;
    return tokens;
  }

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    resetCount++;
    resetAccessToken = accessToken;
    this.newPassword = newPassword;
    this.confirmPassword = confirmPassword;
    if (resetError != null) throw resetError!;
  }
}

Widget _harness(AppState appState, String initialLocation) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/email-sent',
        builder: (_, state) =>
            EmailSentScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: state.uri.queryParameters['purpose'] == 'recovery'
              ? VerificationPurpose.passwordRecovery
              : VerificationPurpose.registration,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('Sign Up screen')),
      ),
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: Text('Home screen')),
      ),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp.router(routerConfig: router),
  );
}

AppState _state(
  _FakeAuthGateway gateway, {
  Future<void> Function(String email)? signupCodeResender,
  Future<RegistrationVerificationSuccess> Function(
    RegistrationVerificationSuccess tokens,
  )?
  recoverySessionRefresher,
  Future<void> Function(String newPassword)? recoveryPasswordFallback,
}) => AppState(
  registrationGateway: gateway,
  verificationSessionHandler: (_) async {},
  signupCodeResender: signupCodeResender,
  recoverySessionRefresher: recoverySessionRefresher,
  recoveryPasswordFallback: recoveryPasswordFallback,
);

Future<void> _enterOtp(WidgetTester tester, String code) async {
  for (var index = 0; index < code.length; index++) {
    await tester.enterText(
      find.byKey(ValueKey('verification-code-$index')),
      code[index],
    );
  }
  await tester.pump();
}

void main() {
  group('Sign In flow', () {
    testWidgets('valid credentials navigate to Home', (tester) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(_harness(state, '/signin'));

      await tester.enterText(
        find.byType(TextField).at(0),
        'person@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'Password1!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('invalid credentials remain on Sign In and show an error', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway()
        ..signInError = const RegistrationException(
          message: 'Email or password is incorrect.',
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
        );
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(_harness(state, '/signin'));

      await tester.enterText(
        find.byType(TextField).at(0),
        'person@example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), 'WrongPassword1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('NaviPet'), findsOneWidget);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.text('Home screen'), findsNothing);
    });
  });

  group('Forgot Password flow', () {
    testWidgets('invalid email shows inline validation', (tester) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(_harness(state, '/forgot-password'));

      await tester.enterText(
        find.byKey(const ValueKey('forgot-password-email')),
        'not-an-email',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Send verification code'),
      );
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(gateway.recoveryRequestCount, 0);
    });

    testWidgets('valid email shows Email Sent then recovery OTP', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(_harness(state, '/forgot-password'));

      await tester.enterText(
        find.byKey(const ValueKey('forgot-password-email')),
        'person@example.com',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Send verification code'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Email sent'), findsOneWidget);
      expect(gateway.recoveryRequestCount, 1);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enter verification code'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verify reset code'), findsNWidgets(2));
    });

    testWidgets('valid recovery OTP opens Reset Password, not Home', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _harness(
          state,
          '/verify-email?email=person%40example.com&purpose=recovery',
        ),
      );

      await _enterOtp(tester, '123456');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Verify reset code'),
      );
      await tester.pumpAndSettle();

      expect(gateway.recoveryVerificationCount, 1);
      expect(find.text('Create a new password'), findsOneWidget);
      expect(find.text('Home screen'), findsNothing);
    });

    testWidgets('mismatched passwords remain on Reset Password', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'person@example.com',
        code: '123456',
      );
      await tester.pumpWidget(_harness(state, '/reset-password'));

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'NewPassword1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'Different1',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(find.text('Create a new password'), findsOneWidget);
      expect(gateway.resetCount, 0);
    });

    testWidgets('successful reset establishes a session and opens Home', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'person@example.com',
        code: '123456',
      );
      await tester.pumpWidget(_harness(state, '/reset-password'));

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'NewPassword1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'NewPassword1!',
      );
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Reset password'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(gateway.resetCount, 1);
      expect(gateway.resetAccessToken, 'access-token');
      expect(gateway.newPassword, 'NewPassword1!');
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('failed password reset shows an error and remains in place', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway()
        ..resetError = const RegistrationException(
          message: 'The recovery session is invalid or expired.',
          statusCode: 401,
          code: 'INVALID_RECOVERY_SESSION',
        );
      final state = _state(gateway);
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'person@example.com',
        code: '123456',
      );
      await tester.pumpWidget(_harness(state, '/reset-password'));

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'NewPassword1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'NewPassword1!',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(
        find.text('The recovery session is invalid or expired.'),
        findsOneWidget,
      );
      expect(find.text('Create a new password'), findsOneWidget);
      expect(find.text('Home screen'), findsNothing);
    });

    testWidgets('refreshes recovery tokens and handles a missing JWT session', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway()
        ..resetError = const RegistrationException(
          message: 'Session from session_id claim in JWT does not exist',
          statusCode: 401,
          code: 'SESSION_NOT_FOUND',
        );
      String? fallbackPassword;
      final state = _state(
        gateway,
        recoverySessionRefresher: (_) async =>
            const RegistrationVerificationSuccess(
              accessToken: 'fresh-recovery-access',
              refreshToken: 'fresh-recovery-refresh',
            ),
        recoveryPasswordFallback: (password) async {
          fallbackPassword = password;
        },
      );
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'person@example.com',
        code: '123456',
      );
      await tester.pumpWidget(_harness(state, '/reset-password'));

      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'NewPassword1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-new-password')),
        'NewPassword1!',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(gateway.resetAccessToken, 'fresh-recovery-access');
      expect(fallbackPassword, 'NewPassword1!');
      expect(find.text('Home screen'), findsOneWidget);
    });
  });

  group('OTP outcomes', () {
    testWidgets('signup resend stays on OTP and reports success', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      var resendCount = 0;
      final state = _state(
        gateway,
        signupCodeResender: (_) async => resendCount++,
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _harness(state, '/verify-email?email=person%40example.com'),
      );

      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(resendCount, 1);
      expect(find.text('A new verification code was sent.'), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
    });

    testWidgets('recovery resend stays on OTP and requests another code', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _harness(
          state,
          '/verify-email?email=person%40example.com&purpose=recovery',
        ),
      );

      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(gateway.recoveryRequestCount, 1);
      expect(find.text('A new verification code was sent.'), findsOneWidget);
      expect(find.text('Verify reset code'), findsNWidgets(2));
    });

    testWidgets('invalid or expired recovery OTP stays and offers resend', (
      tester,
    ) async {
      final gateway = _FakeAuthGateway()
        ..verificationError = const RegistrationException(
          message: 'Invalid verification code.',
          statusCode: 401,
          code: 'INVALID_OTP',
        );
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _harness(
          state,
          '/verify-email?email=person%40example.com&purpose=recovery',
        ),
      );

      await _enterOtp(tester, '000000');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Verify reset code'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'That code is invalid or expired. Request a new code and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resend Code'), findsOneWidget);
      expect(find.text('Create a new password'), findsNothing);
      expect(find.text('Home screen'), findsNothing);
    });

    testWidgets('registration Back returns to Sign Up', (tester) async {
      final gateway = _FakeAuthGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _harness(state, '/verify-email?email=person%40example.com'),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Sign Up screen'), findsOneWidget);
    });
  });
}
