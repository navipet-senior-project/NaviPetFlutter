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

ElevatedButton _submitButton(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, 'Create Account'),
);

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
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

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
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(_submitButton(tester).onPressed, isNotNull);
      },
    );

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
  });

  group('RegisterScreen submission', () {
    testWidgets(
      'shows the confirmation message and does not navigate to /map on success',
      (tester) async {
        final gateway = _FakeRegistrationGateway(
          result: const RegistrationSuccess(
            message: 'Confirmation email sent. Check your inbox.',
            confirmationRequired: true,
          ),
        );
        final appState = AppState(registrationGateway: gateway);
        addTearDown(appState.dispose);
        await tester.pumpWidget(_harness(appState));

        await _fillValidForm(tester);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pumpAndSettle();

        expect(gateway.callCount, 1);
        expect(gateway.capturedFirstName, 'Elbee');
        expect(gateway.capturedLastName, 'Shark');
        expect(
          find.text(
            'Confirmation email sent. Open it on this device to finish signing in.',
          ),
          findsOneWidget,
        );
        expect(find.text('Map screen'), findsNothing);
        expect(appState.isAuthenticated, isFalse);
      },
    );
  });
}
