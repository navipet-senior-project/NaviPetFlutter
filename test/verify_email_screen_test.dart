import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/verify_email_screen.dart';

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
}
