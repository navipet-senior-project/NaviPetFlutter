import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/registration_gateway.dart';

void main() {
  group('HttpRegistrationGateway.register', () {
    test('posts backend field names as JSON to /auth/register', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'message': 'Verification code sent. Check your inbox.',
            'otp_required': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com/',
        client: client,
      );

      final result = await gateway.register(
        firstName: 'Elbee',
        lastName: 'Shark',
        email: 'person@example.com',
        password: 'Password1!',
      );

      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url,
        Uri.parse('https://navipetbackend.onrender.com/auth/register'),
      );
      expect(jsonDecode(capturedRequest.body), {
        'firstName': 'Elbee',
        'lastName': 'Shark',
        'email': 'person@example.com',
        'password': 'Password1!',
      });
      expect(result.message, 'Verification code sent. Check your inbox.');
<<<<<<< Updated upstream
      expect(result.confirmationRequired, isTrue);
=======
      expect(result.otpRequired, isTrue);
    });

    test('posts a registration code and parses session tokens', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com/',
        client: client,
      );

      final result = await gateway.verifyRegistrationCode(
        email: 'person@example.com',
        code: '123456',
      );

      expect(
        capturedRequest.url,
        Uri.parse('https://navipetbackend.onrender.com/auth/verify-otp'),
      );
      expect(jsonDecode(capturedRequest.body), {
        'email': 'person@example.com',
        'code': '123456',
        'type': 'register',
      });
      expect(result.accessToken, 'access-token');
      expect(result.refreshToken, 'refresh-token');
    });

    test('signs in through /auth/login and parses session tokens', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
          }),
          200,
        );
      });
      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com',
        client: client,
      );

      await gateway.signIn(email: 'person@example.com', password: 'Password1!');

      expect(capturedRequest.url.path, '/auth/login');
      expect(jsonDecode(capturedRequest.body), {
        'email': 'person@example.com',
        'password': 'Password1!',
      });
    });

    test('requests and verifies a password recovery code', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/forgot-password') {
          return http.Response(
            jsonEncode({
              'message': 'Verification code sent. Check your inbox.',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'access_token': 'recovery-access',
            'refresh_token': 'recovery-refresh',
          }),
          200,
        );
      });
      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com',
        client: client,
      );

      await gateway.requestPasswordReset(email: 'person@example.com');
      final tokens = await gateway.verifyPasswordRecoveryCode(
        email: 'person@example.com',
        code: '654321',
      );

      expect(requests[0].url.path, '/auth/forgot-password');
      expect(jsonDecode(requests[0].body), {'email': 'person@example.com'});
      expect(requests[1].url.path, '/auth/verify-otp');
      expect(jsonDecode(requests[1].body), {
        'email': 'person@example.com',
        'code': '654321',
        'type': 'recovery',
      });
      expect(tokens.accessToken, 'recovery-access');
    });

    test('resets a password with the recovery bearer token', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      });
      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com',
        client: client,
      );

      await gateway.resetPassword(
        accessToken: 'recovery-access',
        newPassword: 'NewPassword1',
        confirmPassword: 'NewPassword1',
      );

      expect(capturedRequest.url.path, '/auth/reset-password');
      expect(
        capturedRequest.headers['authorization'],
        'Bearer recovery-access',
      );
      expect(jsonDecode(capturedRequest.body), {
        'newPassword': 'NewPassword1',
        'confirmPassword': 'NewPassword1',
      });
>>>>>>> Stashed changes
    });

    test(
      'throws a RegistrationException from the standard error envelope on 429',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'RATE_LIMITED',
                'message': 'Too many requests. Try again later.',
                'requestId': 'req-123',
              },
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        });

        final gateway = HttpRegistrationGateway(
          baseUrl: 'https://navipetbackend.onrender.com',
          client: client,
        );

        await expectLater(
          () => gateway.register(
            firstName: 'Elbee',
            lastName: 'Shark',
            email: 'person@example.com',
            password: 'Password1!',
          ),
          throwsA(
            isA<RegistrationException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having((e) => e.code, 'code', 'RATE_LIMITED')
                .having(
                  (e) => e.message,
                  'message',
                  'Too many requests. Try again later.',
                ),
          ),
        );
      },
    );

    test(
      'falls back to a generic message when the error body is not the standard envelope',
      () async {
        final client = MockClient((request) async {
          return http.Response('not json', 500);
        });

        final gateway = HttpRegistrationGateway(
          baseUrl: 'https://navipetbackend.onrender.com',
          client: client,
        );

        await expectLater(
          () => gateway.register(
            firstName: 'Elbee',
            lastName: 'Shark',
            email: 'person@example.com',
            password: 'Password1!',
          ),
          throwsA(
            isA<RegistrationException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.message, 'message', isNotEmpty),
          ),
        );
      },
    );
  });

  group('HttpRegistrationGateway authentication flow', () {
    test('uses the documented login and recovery endpoints', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/reset-password') {
          return http.Response('', 204);
        }
        if (request.url.path == '/auth/forgot-password') {
          return http.Response(
            jsonEncode({
              'message': 'Verification code sent. Check your inbox.',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
          }),
          200,
        );
      });
      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com/',
        client: client,
      );

      final login = await gateway.login(
        email: 'person@example.com',
        password: 'Password1!',
      );
      await gateway.requestPasswordReset('person@example.com');
      final recovery = await gateway.verifyOtp(
        email: 'person@example.com',
        code: '123456',
        isPasswordRecovery: true,
      );
      await gateway.resetPassword(
        accessToken: recovery.accessToken,
        newPassword: 'NewPassword1',
      );

      expect(login.refreshToken, 'refresh-token');
      expect(requests.map((request) => request.url.path), [
        '/auth/login',
        '/auth/forgot-password',
        '/auth/verify-otp',
        '/auth/reset-password',
      ]);
      expect(jsonDecode(requests[2].body), {
        'email': 'person@example.com',
        'code': '123456',
        'type': 'recovery',
      });
      expect(requests[3].headers['authorization'], 'Bearer access-token');
      expect(jsonDecode(requests[3].body), {
        'newPassword': 'NewPassword1',
        'confirmPassword': 'NewPassword1',
      });
    });
  });
}
