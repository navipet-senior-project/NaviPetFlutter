import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/register_screen.dart';

class _FakeRegistrationGateway implements RegistrationGateway {
  // ignore: unused_element_parameter
  _FakeRegistrationGateway({this.result, this.error});

  RegistrationSuccess? result;
  RegistrationException? error;
  int callCount = 0;
  String? capturedFirstName;
  String? capturedLastName;
  String? capturedEmail;
  String? capturedPassword;

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
  }) async {
    callCount++;
    capturedFirstName = firstName;
    capturedLastName = lastName;
    capturedEmail = email;
    capturedPassword = password;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    if (error != null) throw error!;
    return const RegistrationVerificationSuccess(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async => const PasswordResetRequestSuccess(
    message: 'Verification code sent. Check your inbox.',
  );

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
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/signin',
        builder: (_, _) => const Scaffold(body: Text('Sign in screen')),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
<<<<<<< Updated upstream
        path: '/check-email',
        builder: (_, state) => Scaffold(
          body: Text('Check email: ${state.uri.queryParameters['email']}'),
=======
        path: '/verify-email',
        builder: (_, state) => Scaffold(
          body: Text('Verify ${state.uri.queryParameters['email'] ?? ''}'),
>>>>>>> Stashed changes
        ),
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

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Elbee');
  await tester.enterText(find.byType(TextField).at(1), 'Shark');
  await tester.enterText(find.byType(TextField).at(2), 'person@example.com');
  await tester.enterText(find.byType(TextField).at(3), 'Password1!');
  await tester.enterText(find.byType(TextField).at(4), 'Password1!');
  await tester.pump();
}

ElevatedButton _submitButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
<<<<<<< Updated upstream
      find.widgetWithText(ElevatedButton, 'Create account'),
    );

Future<void> _acceptTerms(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}
=======
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );
>>>>>>> Stashed changes

void main() {
  group('RegisterScreen validation', () {
    testWidgets('shows an inline error for an invalid email format', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await tester.enterText(find.byType(TextField).at(2), 'not-an-email');
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets(
      'shows an inline error and disables submit when passwords do not match',
      (tester) async {
        final appState = AppState(
          registrationGateway: _FakeRegistrationGateway(),
        );
        addTearDown(appState.dispose);
        await tester.pumpWidget(_harness(appState));

        await tester.enterText(find.byType(TextField).at(0), 'Elbee');
        await tester.enterText(find.byType(TextField).at(1), 'Shark');
        await tester.enterText(
          find.byType(TextField).at(2),
          'person@example.com',
        );
        await tester.enterText(find.byType(TextField).at(3), 'Password1!');
        await tester.enterText(find.byType(TextField).at(4), 'Password2!');
        await _acceptTerms(tester);

        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(_submitButton(tester).onPressed, isNull);
      },
    );

    testWidgets('disables submit when the terms checkbox is unchecked', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await _fillValidForm(tester);

      expect(_submitButton(tester).onPressed, isNull);
    });

    testWidgets(
      'enables submit once every field is valid and terms are accepted',
      (tester) async {
        final appState = AppState(
          registrationGateway: _FakeRegistrationGateway(),
        );
        addTearDown(appState.dispose);
        await tester.pumpWidget(_harness(appState));

        await _fillValidForm(tester);
        await _acceptTerms(tester);

        expect(_submitButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets('shows a green check for every satisfied password rule', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await tester.enterText(find.byType(TextField).at(3), 'Password1!');
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
    });

    testWidgets('keeps submit disabled when any password rule is unmet', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await _fillValidForm(tester);
      await tester.enterText(find.byType(TextField).at(3), 'password1!');
      await tester.enterText(find.byType(TextField).at(4), 'password1!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(_submitButton(tester).onPressed, isNull);
      expect(
        find.byKey(
          const ValueKey('password-requirement-unmet-One uppercase letter'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('back arrow returns to the sign-in screen', (tester) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Sign in screen'), findsOneWidget);
    });

    testWidgets('Already have an account navigates to Sign In', (tester) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in screen'), findsOneWidget);
    });

    testWidgets('opens verification for an existing code and valid email', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await tester.enterText(
        find.byType(TextField).at(2),
        'person@example.com',
      );
      await tester.tap(find.text('Already have a verification code?'));
      await tester.pumpAndSettle();

      expect(find.text('Verify person@example.com'), findsOneWidget);
    });
  });

  group('RegisterScreen submission', () {
    testWidgets('shows a clear message when the email already has an account', (
      tester,
    ) async {
      final gateway = _FakeRegistrationGateway(
        error: const RegistrationException(
          message: 'User already registered',
          statusCode: 409,
          code: 'USER_ALREADY_EXISTS',
        ),
      );
      final appState = AppState(registrationGateway: gateway);
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await _fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text(
          'An account with this email already exists. Please log in or use a different email.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verify person@example.com'), findsNothing);
    });

    testWidgets(
<<<<<<< Updated upstream
      'opens the check-email screen and does not navigate to /map on success',
=======
      'opens code verification with the registered email on success',
>>>>>>> Stashed changes
      (tester) async {
        final gateway = _FakeRegistrationGateway(
          result: const RegistrationSuccess(
            message: 'Verification code sent. Check your inbox.',
            otpRequired: true,
          ),
        );
        final appState = AppState(registrationGateway: gateway);
        addTearDown(appState.dispose);
        await tester.pumpWidget(_harness(appState));

        await _fillValidForm(tester);
        await _acceptTerms(tester);
        final submit = find.widgetWithText(ElevatedButton, 'Create account');
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(gateway.callCount, 1);
        expect(gateway.capturedFirstName, 'Elbee');
        expect(gateway.capturedLastName, 'Shark');
<<<<<<< Updated upstream
        expect(find.text('Check email: person@example.com'), findsOneWidget);
=======
        expect(find.text('Verify person@example.com'), findsOneWidget);
>>>>>>> Stashed changes
        expect(find.text('Map screen'), findsNothing);
        expect(appState.isAuthenticated, isFalse);
      },
    );
  });
}
