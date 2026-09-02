import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';

/// Records every backend call so the tests can assert the exact sequence the
/// reset flow is allowed to make. Any Supabase traffic would throw instead,
/// because these AppStates are built without a SupabaseClient.
class _FakeBackendGateway implements BackendAuthGateway {
  _FakeBackendGateway({this.resetError});

  static const otpTokens = AuthTokens(
    accessToken: 'recovery-access',
    refreshToken: 'recovery-refresh',
  );

  final RegistrationException? resetError;

  final List<String> calls = <String>[];
  String? resetAccessToken;
  String? capturedNewPassword;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    calls.add('login');
    return otpTokens;
  }

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    calls.add('register');
    return const RegistrationSuccess(message: 'ok', confirmationRequired: true);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add('forgot-password');
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
    required bool isPasswordRecovery,
  }) async {
    calls.add('verify-otp');
    return otpTokens;
  }

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
  }) async {
    calls.add('reset-password');
    resetAccessToken = accessToken;
    capturedNewPassword = newPassword;
    if (resetError != null) throw resetError!;
  }
}

void main() {
  group('AppState password reset against the backend gateway', () {
    test(
      'verifying a recovery code holds the session without touching Supabase',
      () async {
        final gateway = _FakeBackendGateway();
        final state = AppState(registrationGateway: gateway);
        addTearDown(state.dispose);

        final result = await state.verifyEmailCode(
          email: 'student@example.com',
          code: '123456',
          isPasswordRecovery: true,
        );

        expect(result.status, AuthActionStatus.passwordRecoveryReady);
        expect(gateway.calls, ['verify-otp']);
        // Reaching for a SupabaseClient here would have thrown a StateError and
        // surfaced as a failure result, so a clean pass proves no SDK call.
        expect(state.hasPasswordRecoverySession, isTrue);
        expect(state.isAuthenticated, isFalse);
      },
    );

    test('reuses the verify-otp access token for reset-password', () async {
      final gateway = _FakeBackendGateway();
      final state = AppState(registrationGateway: gateway);
      addTearDown(state.dispose);

      await state.verifyEmailCode(
        email: 'student@example.com',
        code: '123456',
        isPasswordRecovery: true,
      );
      final result = await state.updatePassword('Password1');

      expect(result.status, AuthActionStatus.passwordUpdated);
      expect(gateway.calls, ['verify-otp', 'reset-password']);
      expect(gateway.resetAccessToken, 'recovery-access');
      expect(gateway.capturedNewPassword, 'Password1');
      expect(state.hasPasswordRecoverySession, isFalse);
    });

    test('a second submit fails locally instead of hitting the API', () async {
      final gateway = _FakeBackendGateway();
      final state = AppState(registrationGateway: gateway);
      addTearDown(state.dispose);

      await state.verifyEmailCode(
        email: 'student@example.com',
        code: '123456',
        isPasswordRecovery: true,
      );
      await state.updatePassword('Password1');
      final second = await state.updatePassword('Password1');

      expect(second.status, AuthActionStatus.failure);
      expect(second.code, 'INVALID_ACCESS_TOKEN');
      expect(gateway.calls, ['verify-otp', 'reset-password']);
    });

    test('an INVALID_ACCESS_TOKEN drops the session so the flow can restart',
        () async {
      final gateway = _FakeBackendGateway(
        resetError: const RegistrationException(
          message: 'Your password reset session has expired.',
          statusCode: 401,
          code: 'INVALID_ACCESS_TOKEN',
        ),
      );
      final state = AppState(registrationGateway: gateway);
      addTearDown(state.dispose);

      await state.verifyEmailCode(
        email: 'student@example.com',
        code: '123456',
        isPasswordRecovery: true,
      );
      final result = await state.updatePassword('Password1');

      expect(result.status, AuthActionStatus.failure);
      expect(result.code, 'INVALID_ACCESS_TOKEN');
      expect(state.hasPasswordRecoverySession, isFalse);
    });

    test('a VALIDATION_ERROR keeps the session so the user can retry',
        () async {
      final gateway = _FakeBackendGateway(
        resetError: const RegistrationException(
          message: 'Password must be different from your previous password.',
          statusCode: 422,
          code: 'VALIDATION_ERROR',
        ),
      );
      final state = AppState(registrationGateway: gateway);
      addTearDown(state.dispose);

      await state.verifyEmailCode(
        email: 'student@example.com',
        code: '123456',
        isPasswordRecovery: true,
      );
      final result = await state.updatePassword('Password1');

      expect(result.status, AuthActionStatus.failure);
      expect(result.code, 'VALIDATION_ERROR');
      expect(
        result.message,
        'Password must be different from your previous password.',
      );
      expect(state.hasPasswordRecoverySession, isTrue);
    });
  });
}
