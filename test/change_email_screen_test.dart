import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:navipet/screens/change_email_screen.dart';
import 'package:provider/provider.dart';

import 'email_change_test_support.dart';

const _field = ValueKey('change-email-field');
const _passwordField = ValueKey('change-email-password-field');
const _submit = ValueKey('change-email-submit');

Widget _app(AppState state, {String location = '/account/email'}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/account',
        builder: (_, _) => const Scaffold(body: Text('Account screen')),
      ),
      GoRoute(
        path: '/account/email',
        builder: (_, state) => ChangeEmailScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
          requirePassword: state.uri.queryParameters['reauth'] == '1',
        ),
      ),
      GoRoute(
        path: '/account/email/verify',
        builder: (_, state) => Scaffold(
          body: Text('Verify ${state.uri.queryParameters['email']}'),
        ),
      ),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the current email and one field', (tester) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    expect(find.text('Current email: $currentTestEmail'), findsOneWidget);
    expect(find.byKey(_field), findsOneWidget);
    expect(find.byKey(_passwordField), findsNothing);
    expect(find.text('Send verification code'), findsOneWidget);
  });

  testWidgets('rejects a malformed address without sending anything', (
    tester,
  ) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'not-an-email');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(harness.gateway.requests, isEmpty);
  });

  testWidgets('rejects the current address without sending anything', (
    tester,
  ) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), ' Jane@Student.CSULB.edu ');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter an email that is different from your current one.'),
      findsOneWidget,
    );
    expect(harness.gateway.requests, isEmpty);
  });

  testWidgets('sends the code and opens the code screen', (tester) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'New@Example.com');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(harness.gateway.requests, [
      (accessToken: 'stale-token', newEmail: 'new@example.com'),
    ]);
    expect(find.text('Verify new@example.com'), findsOneWidget);
  });

  testWidgets('asks for the password on REAUTH_REQUIRED, then completes', (
    tester,
  ) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    harness.gateway.requestErrors.add(reauthRequiredError);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'new@example.com');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(find.byKey(_passwordField), findsOneWidget);
    expect(
      find.text('For your security, enter your password to continue.'),
      findsOneWidget,
    );
    expect(find.text('Confirm password and send code'), findsOneWidget);

    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(harness.gateway.signIns, isEmpty);

    await tester.enterText(find.byKey(_passwordField), 'Password1!');
    await tester.ensureVisible(find.byKey(_submit));
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(harness.gateway.signIns, [
      (email: currentTestEmail, password: 'Password1!'),
    ]);
    expect(harness.installed.single.accessToken, 'login-access');
    expect(harness.gateway.requests.last, (
      accessToken: 'login-access',
      newEmail: 'new@example.com',
    ));
    expect(find.text('Verify new@example.com'), findsOneWidget);
  });

  testWidgets('opens on the password step from the URL and reports a wrong '
      'password', (tester) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    harness.gateway.signInError = const RegistrationException(
      message: 'Email or password is incorrect.',
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
    );
    await tester.pumpWidget(
      _app(
        harness.state,
        location: '/account/email?email=new%40example.com&reauth=1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('new@example.com'), findsOneWidget);
    expect(find.byKey(_passwordField), findsOneWidget);

    await tester.enterText(find.byKey(_passwordField), 'wrong');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(find.text('That password is incorrect.'), findsOneWidget);
    expect(find.byType(ChangeEmailScreen), findsOneWidget);
    expect(harness.gateway.requests, isEmpty);
  });

  testWidgets('shows the rate-limit text and stays on the screen', (
    tester,
  ) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    harness.gateway.requestErrors.add(
      const RegistrationException(
        message: 'Too many requests.',
        statusCode: 429,
        code: 'RATE_LIMITED',
      ),
    );
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'new@example.com');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Wait a few minutes and try again.'),
      findsOneWidget,
    );
    expect(find.byType(ChangeEmailScreen), findsOneWidget);
  });

  testWidgets('back returns to Account when there is nothing to pop', (
    tester,
  ) async {
    final harness = await EmailChangeHarness.create(tester);
    addTearDown(harness.state.dispose);
    await tester.pumpWidget(_app(harness.state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Account screen'), findsOneWidget);
  });
}
