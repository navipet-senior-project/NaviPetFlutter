import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/email_change.dart';
import 'package:navipet/data/registration_gateway.dart';

import 'email_change_test_support.dart';

void main() {
  group('canChangeEmail', () {
    testWidgets('is true for a signed-in account', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);

      expect(harness.state.activeUser?.email, currentTestEmail);
      expect(harness.state.canChangeEmail, isTrue);
    });

    testWidgets('is false for a guest', (tester) async {
      final harness = await EmailChangeHarness.create(tester, anonymous: true);
      addTearDown(harness.state.dispose);

      expect(harness.state.activeUser?.isAnonymous, isTrue);
      expect(harness.state.canChangeEmail, isFalse);
    });
  });

  group('requestEmailChange', () {
    testWidgets('sends the current token and the normalised email', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);

      final result = await harness.state.requestEmailChange(
        '  New@Example.com ',
      );

      expect(result.status, EmailChangeStatus.codeSent);
      expect(harness.gateway.requests, [
        (accessToken: 'stale-token', newEmail: 'new@example.com'),
      ]);
      expect(harness.tokens.calls, [false]);
      expect(harness.state.isBusy, isFalse);
    });

    testWidgets('refreshes the token once and retries once', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.requestErrors.add(
        const RegistrationException(
          message: 'Invalid token.',
          statusCode: 401,
          code: 'INVALID_ACCESS_TOKEN',
        ),
      );

      final result = await harness.state.requestEmailChange('new@example.com');

      expect(result.status, EmailChangeStatus.codeSent);
      expect(harness.tokens.calls, [false, true]);
      expect(harness.gateway.requests.map((r) => r.accessToken), [
        'stale-token',
        'fresh-token',
      ]);
    });

    testWidgets('reports an expired session when the retry also fails', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      const invalid = RegistrationException(
        message: 'Invalid token.',
        statusCode: 401,
        code: 'INVALID_ACCESS_TOKEN',
      );
      harness.gateway.requestErrors.addAll([invalid, invalid]);

      final result = await harness.state.requestEmailChange('new@example.com');

      expect(result.status, EmailChangeStatus.failure);
      expect(
        result.message,
        'Your session has expired. Sign in again to change your email.',
      );
      expect(harness.gateway.requests, hasLength(2));
    });

    testWidgets('reports an expired session when there is no token', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.tokens.current = null;

      final result = await harness.state.requestEmailChange('new@example.com');

      expect(result.status, EmailChangeStatus.failure);
      expect(
        result.message,
        'Your session has expired. Sign in again to change your email.',
      );
      expect(harness.gateway.requests, isEmpty);
    });

    testWidgets('returns reauthRequired for REAUTH_REQUIRED', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.requestErrors.add(reauthRequiredError);

      final result = await harness.state.requestEmailChange('new@example.com');

      expect(result.status, EmailChangeStatus.reauthRequired);
      expect(harness.gateway.requests, hasLength(1));
      expect(harness.tokens.calls, [false]);
    });

    testWidgets('maps a rate limit', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.requestErrors.add(
        const RegistrationException(
          message: 'Too many requests.',
          statusCode: 429,
          code: 'RATE_LIMITED',
        ),
      );

      final result = await harness.state.requestEmailChange('new@example.com');

      expect(result.status, EmailChangeStatus.failure);
      expect(
        result.message,
        'Too many attempts. Wait a few minutes and try again.',
      );
      expect(result.errorCode, 'RATE_LIMITED');
      expect(result.statusCode, 429);
    });
  });

  group('reauthenticateAndRequestEmailChange', () {
    testWidgets(
      'signs in with the current email, stores the session, and retries',
      (tester) async {
        final harness = await EmailChangeHarness.create(tester);
        addTearDown(harness.state.dispose);

        final result = await harness.state.reauthenticateAndRequestEmailChange(
          newEmail: 'New@Example.com',
          password: 'Password1!',
        );

        expect(result.status, EmailChangeStatus.codeSent);
        expect(harness.gateway.signIns, [
          (email: currentTestEmail, password: 'Password1!'),
        ]);
        expect(harness.installed.single.accessToken, 'login-access');
        expect(harness.gateway.requests, [
          (accessToken: 'login-access', newEmail: 'new@example.com'),
        ]);
        expect(harness.tokens.calls, isEmpty);
      },
    );

    testWidgets('reports a wrong password and sends nothing', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.signInError = const RegistrationException(
        message: 'Email or password is incorrect.',
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
      );

      final result = await harness.state.reauthenticateAndRequestEmailChange(
        newEmail: 'new@example.com',
        password: 'wrong',
      );

      expect(result.status, EmailChangeStatus.failure);
      expect(result.message, 'That password is incorrect.');
      expect(harness.installed, isEmpty);
      expect(harness.gateway.requests, isEmpty);
    });

    testWidgets('does not loop when the backend still asks for reauth', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.requestErrors.add(reauthRequiredError);

      final result = await harness.state.reauthenticateAndRequestEmailChange(
        newEmail: 'new@example.com',
        password: 'Password1!',
      );

      expect(result.status, EmailChangeStatus.failure);
      expect(result.message, 'We could not send the code. Please try again.');
      expect(harness.gateway.requests, hasLength(1));
    });
  });

  group('confirmEmailChange', () {
    testWidgets('installs the returned session and returns the message', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      final standard = tokenWithPurpose('standard');
      harness.gateway.verifyResult = EmailChangeVerificationSuccess(
        tokens: RegistrationVerificationSuccess(
          accessToken: standard,
          refreshToken: 'new-refresh',
        ),
        message: 'Email updated. Use this email the next time you sign in.',
      );

      final result = await harness.state.confirmEmailChange(
        newEmail: ' New@Example.com',
        code: '123456',
      );

      expect(result.status, EmailChangeStatus.changed);
      expect(
        result.message,
        'Email updated. Use this email the next time you sign in.',
      );
      expect(harness.gateway.verifications, [
        (newEmail: 'new@example.com', code: '123456'),
      ]);
      expect(harness.installed.single.accessToken, standard);
      expect(harness.installed.single.refreshToken, 'new-refresh');
      expect(harness.discardCount, 0);
    });

    testWidgets('discards the session for a recovery-purpose token', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.verifyResult = EmailChangeVerificationSuccess(
        tokens: RegistrationVerificationSuccess(
          accessToken: tokenWithPurpose('recovery'),
          refreshToken: 'recovery-refresh',
        ),
        message: 'Email updated. Use this email the next time you sign in.',
      );

      final result = await harness.state.confirmEmailChange(
        newEmail: 'new@example.com',
        code: '123456',
      );

      expect(result.status, EmailChangeStatus.changedSignInRequired);
      expect(result.message, emailChangeSignInNotice);
      expect(harness.installed, isEmpty);
      expect(harness.discardCount, 1);
      expect(harness.state.activeUser, isNull);
    });

    testWidgets('discards the session when it cannot be installed', (
      tester,
    ) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.installError = StateError('storage unavailable');

      final result = await harness.state.confirmEmailChange(
        newEmail: 'new@example.com',
        code: '123456',
      );

      expect(result.status, EmailChangeStatus.changedSignInRequired);
      expect(result.message, emailChangeSignInNotice);
      expect(harness.discardCount, 1);
    });

    testWidgets('maps a wrong code and keeps the session', (tester) async {
      final harness = await EmailChangeHarness.create(tester);
      addTearDown(harness.state.dispose);
      harness.gateway.verifyError = const RegistrationException(
        message: 'Invalid or expired code.',
        statusCode: 401,
        code: 'INVALID_OTP',
      );

      final result = await harness.state.confirmEmailChange(
        newEmail: 'new@example.com',
        code: '000000',
      );

      expect(result.status, EmailChangeStatus.failure);
      expect(
        result.message,
        'That code is invalid or expired. Request a new code and try again.',
      );
      expect(harness.installed, isEmpty);
      expect(harness.discardCount, 0);
      expect(harness.state.activeUser, isNotNull);
      expect(harness.state.isBusy, isFalse);
    });
  });
}
