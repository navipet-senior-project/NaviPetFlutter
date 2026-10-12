import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';

class _FakeRegistrationGateway implements RegistrationGateway {
  static const recoveryTokens = RegistrationVerificationSuccess(
    accessToken: 'recovery-access',
    refreshToken: 'recovery-refresh',
  );

  RegistrationException? resetError;
  final List<String> calls = [];
  String? resetAccessToken;
  String? capturedNewPassword;

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) async => recoveryTokens;

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) async => const RegistrationSuccess(message: 'ok', otpRequired: true);

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) async => recoveryTokens;

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async => const PasswordResetRequestSuccess(message: 'sent');

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) async {
    calls.add('verify-otp');
    return recoveryTokens;
  }

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    calls.add('reset-password');
    resetAccessToken = accessToken;
    capturedNewPassword = newPassword;
    if (resetError != null) throw resetError!;
  }
}

AppState _state(_FakeRegistrationGateway gateway) => AppState(
  registrationGateway: gateway,
  recoverySessionRefresher: (tokens) async => tokens,
);

void main() {
  group('AppState password recovery', () {
    test('holds the recovery session after verifying the OTP', () async {
      final gateway = _FakeRegistrationGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);

      final result = await state.verifyPasswordRecoveryCode(
        email: 'student@example.com',
        code: '123456',
      );

      expect(result.status, AuthActionStatus.passwordRecoveryVerified);
      expect(gateway.calls, ['verify-otp']);
      expect(state.hasPendingPasswordRecovery, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('uses the verified access token to reset the password', () async {
      final gateway = _FakeRegistrationGateway();
      final state = _state(gateway);
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'student@example.com',
        code: '123456',
      );

      final result = await state.resetPassword(
        newPassword: 'Password1!',
        confirmPassword: 'Password1!',
      );

      expect(result.status, AuthActionStatus.authenticated);
      expect(gateway.calls, ['verify-otp', 'reset-password']);
      expect(gateway.resetAccessToken, 'recovery-access');
      expect(gateway.capturedNewPassword, 'Password1!');
      expect(state.hasPendingPasswordRecovery, isFalse);
    });

    test('keeps a recoverable session after a validation error', () async {
      final gateway = _FakeRegistrationGateway()
        ..resetError = const RegistrationException(
          message: 'Password must be different from your previous password.',
          statusCode: 422,
          code: 'VALIDATION_ERROR',
        );
      final state = _state(gateway);
      addTearDown(state.dispose);
      await state.verifyPasswordRecoveryCode(
        email: 'student@example.com',
        code: '123456',
      );

      final result = await state.resetPassword(
        newPassword: 'Password1!',
        confirmPassword: 'Password1!',
      );

      expect(result.status, AuthActionStatus.failure);
      expect(result.errorCode, 'VALIDATION_ERROR');
      expect(state.hasPendingPasswordRecovery, isTrue);
    });
  });
}
