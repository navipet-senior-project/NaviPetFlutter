import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/registration_gateway.dart';

class _FakeRegistrationGateway implements RegistrationGateway {
  _FakeRegistrationGateway.success(this._result) : _error = null;
  _FakeRegistrationGateway.failure(this._error) : _result = null;

  final RegistrationSuccess? _result;
  final RegistrationException? _error;

  String? capturedFirstName;
  String? capturedLastName;
  String? capturedEmail;
  String? capturedPassword;
  int callCount = 0;
  String? capturedVerificationEmail;
  String? capturedCode;

  RegistrationVerificationSuccess get _tokens =>
      const RegistrationVerificationSuccess(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) async {
    if (_error != null) throw _error;
    return _tokens;
  }

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
    if (_error != null) throw _error;
    return _result!;
  }

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    capturedVerificationEmail = email;
    capturedCode = code;
    if (_error != null) throw _error;
    return _tokens;
  }

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async {
    if (_error != null) throw _error;
    return const PasswordResetRequestSuccess(
      message: 'Verification code sent. Check your inbox.',
    );
  }

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) async {
    if (_error != null) throw _error;
    return _tokens;
  }

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_error != null) throw _error;
  }
}

void main() {
  group('AppState.signUp with a RegistrationGateway', () {
    test(
      'forwards first and last name separately and stays signed out on success',
      () async {
        final gateway = _FakeRegistrationGateway.success(
          const RegistrationSuccess(
            message: 'Verification code sent. Check your inbox.',
            otpRequired: true,
          ),
        );
        final state = AppState(registrationGateway: gateway);
        addTearDown(state.dispose);

        final result = await state.signUp(
          firstName: 'Elbee',
          lastName: 'Shark',
          email: 'person@example.com',
          password: 'Password1!',
        );

        expect(gateway.callCount, 1);
        expect(gateway.capturedFirstName, 'Elbee');
        expect(gateway.capturedLastName, 'Shark');
        expect(gateway.capturedEmail, 'person@example.com');
        expect(gateway.capturedPassword, 'Password1!');

        expect(result.status, AuthActionStatus.emailVerificationRequired);
        expect(result.message, 'Verification code sent. Check your inbox.');
        expect(state.isAuthenticated, isFalse);
      },
    );

    test('maps a RegistrationException to AuthActionResult.failure', () async {
      final gateway = _FakeRegistrationGateway.failure(
        const RegistrationException(
          message: 'Too many requests. Try again later.',
          statusCode: 429,
          code: 'RATE_LIMITED',
        ),
      );
      final state = AppState(registrationGateway: gateway);
      addTearDown(state.dispose);

      final result = await state.signUp(
        firstName: 'Elbee',
        lastName: 'Shark',
        email: 'person@example.com',
        password: 'Password1!',
      );

      expect(result.status, AuthActionStatus.failure);
      expect(result.message, 'Too many requests. Try again later.');
      expect(state.isAuthenticated, isFalse);
    });

    test('verifies the code and establishes the returned session', () async {
      final gateway = _FakeRegistrationGateway.success(
        const RegistrationSuccess(
          message: 'Verification code sent. Check your inbox.',
          otpRequired: true,
        ),
      );
      RegistrationVerificationSuccess? capturedTokens;
      final state = AppState(
        registrationGateway: gateway,
        verificationSessionHandler: (tokens) async {
          capturedTokens = tokens;
        },
      );
      addTearDown(state.dispose);

      final result = await state.verifyRegistrationCode(
        email: ' person@example.com ',
        code: ' 123456 ',
      );

      expect(result.status, AuthActionStatus.authenticated);
      expect(gateway.capturedVerificationEmail, 'person@example.com');
      expect(gateway.capturedCode, '123456');
      expect(capturedTokens?.accessToken, 'access-token');
      expect(capturedTokens?.refreshToken, 'refresh-token');
    });
  });
}
