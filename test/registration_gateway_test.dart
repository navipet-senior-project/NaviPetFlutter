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
            'message': 'Confirmation email sent. Check your inbox.',
            'confirmation_required': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gateway = HttpRegistrationGateway(
        baseUrl: 'https://navipetbackend.onrender.com',
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
      expect(result.message, 'Confirmation email sent. Check your inbox.');
      expect(result.confirmationRequired, isTrue);
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
}
