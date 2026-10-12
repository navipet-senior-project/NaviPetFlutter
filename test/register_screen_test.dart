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
  String? capturedRole;

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
  }) async {
    callCount++;
    capturedFirstName = firstName;
    capturedLastName = lastName;
    capturedEmail = email;
    capturedPassword = password;
    capturedRole = role;
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
        path: '/verify-email',
        builder: (_, state) => Scaffold(
          body: Text('Verify ${state.uri.queryParameters['email'] ?? ''}'),
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

Future<void> _fillValidForm(
  WidgetTester tester, {
  String? role = 'Student',
}) async {
  await tester.enterText(find.byType(TextField).at(0), 'Elbee');
  await tester.enterText(find.byType(TextField).at(1), 'Shark');
  await tester.enterText(find.byType(TextField).at(2), 'person@example.com');
  await tester.enterText(find.byType(TextField).at(3), 'Password1!');
  await tester.enterText(find.byType(TextField).at(4), 'Password1!');
  if (role != null) {
    final dropdown = find.byKey(const ValueKey('registration-role'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(role).last);
  }
  await tester.pump();
}

ElevatedButton _submitButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create account'),
    );

Future<void> _acceptTerms(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

void main() {
  group('RegisterScreen validation', () {
    testWidgets('requires a role and offers exactly Student and Professor', (
      tester,
    ) async {
      final appState = AppState(
        registrationGateway: _FakeRegistrationGateway(),
      );
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('registration-role')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value).toList(), [
        'student',
        'professor',
      ]);
      await _fillValidForm(tester, role: null);
      await _acceptTerms(tester);
      expect(_submitButton(tester).onPressed, isNull);
    });

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
      await _acceptTerms(tester);
      await tester.pumpAndSettle();

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
      final verificationLink = find.text('Already have a verification code?');
      await tester.ensureVisible(verificationLink);
      await tester.tap(verificationLink);
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
      await _acceptTerms(tester);
      final submit = find.widgetWithText(ElevatedButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
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
      'opens code verification with the registered email on success',
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
        expect(gateway.capturedRole, 'student');
        expect(find.text('Verify person@example.com'), findsOneWidget);
        expect(find.text('Map screen'), findsNothing);
        expect(appState.isAuthenticated, isFalse);
      },
    );

    testWidgets('sends Professor when selected', (tester) async {
      final gateway = _FakeRegistrationGateway(
        result: const RegistrationSuccess(message: 'Sent', otpRequired: true),
      );
      final appState = AppState(registrationGateway: gateway);
      addTearDown(appState.dispose);
      await tester.pumpWidget(_harness(appState));

      await _fillValidForm(tester, role: 'Professor');
      await _acceptTerms(tester);
      final submit = find.widgetWithText(ElevatedButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(gateway.capturedRole, 'professor');
    });
  });
}
