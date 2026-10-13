import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/email_change.dart';
import 'package:navipet/data/registration_gateway.dart';

String _token(Map<String, Object?> claims) {
  String part(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'ES256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

RegistrationException _error(int status, [String? code]) =>
    RegistrationException(
      message: 'backend message',
      statusCode: status,
      code: code,
    );

void main() {
  group('normalizeEmail', () {
    test('trims and lowercases', () {
      expect(normalizeEmail('  New@Example.COM '), 'new@example.com');
    });
  });

  group('validateNewEmail', () {
    const current = 'jane@student.csulb.edu';

    test('accepts a different, well-formed address', () {
      expect(validateNewEmail('new@example.com', currentEmail: current), null);
    });

    test('rejects malformed addresses', () {
      for (final candidate in [
        '',
        'jane',
        'jane@',
        '@example.com',
        'a b@c.d',
      ]) {
        expect(
          validateNewEmail(candidate, currentEmail: current),
          'Enter a valid email address.',
          reason: candidate,
        );
      }
    });

    test('rejects the current address regardless of case or spaces', () {
      expect(
        validateNewEmail(' Jane@Student.CSULB.edu ', currentEmail: current),
        'Enter an email that is different from your current one.',
      );
    });
  });

  group('emailChangeErrorMessage', () {
    test('keeps the gateway message for network and timeout errors', () {
      for (final step in EmailChangeStep.values) {
        expect(emailChangeErrorMessage(_error(0), step), 'backend message');
        expect(emailChangeErrorMessage(_error(408), step), 'backend message');
      }
    });

    test('maps 429 to the rate-limit text at every step', () {
      for (final step in EmailChangeStep.values) {
        expect(
          emailChangeErrorMessage(_error(429, 'RATE_LIMITED'), step),
          'Too many attempts. Wait a few minutes and try again.',
        );
      }
    });

    test('request step', () {
      const step = EmailChangeStep.request;
      expect(
        emailChangeErrorMessage(_error(401, 'INVALID_ACCESS_TOKEN'), step),
        'Your session has expired. Sign in again to change your email.',
      );
      expect(
        emailChangeErrorMessage(_error(422, 'VALIDATION_ERROR'), step),
        'Enter a valid email address that is different from your current one.',
      );
      for (final error in [
        _error(400, 'INVALID_JSON'),
        _error(502, 'INTERNAL_ERROR'),
        _error(502, 'UPSTREAM_ERROR'),
        _error(401, 'REAUTH_REQUIRED'),
      ]) {
        expect(
          emailChangeErrorMessage(error, step),
          'We could not send the code. Please try again.',
          reason: '${error.statusCode} ${error.code}',
        );
      }
    });

    test('reauthenticate step', () {
      const step = EmailChangeStep.reauthenticate;
      expect(
        emailChangeErrorMessage(_error(401, 'INVALID_CREDENTIALS'), step),
        'That password is incorrect.',
      );
      expect(
        emailChangeErrorMessage(_error(403, 'ACCOUNT_DISABLED'), step),
        'backend message',
      );
      expect(
        emailChangeErrorMessage(_error(422, 'VALIDATION_ERROR'), step),
        'Enter your password.',
      );
      expect(
        emailChangeErrorMessage(_error(502, 'UPSTREAM_ERROR'), step),
        'We could not confirm your password. Please try again.',
      );
    });

    test('verify step', () {
      const step = EmailChangeStep.verify;
      expect(
        emailChangeErrorMessage(_error(401, 'INVALID_OTP'), step),
        'That code is invalid or expired. Request a new code and try again.',
      );
      expect(
        emailChangeErrorMessage(_error(422, 'VALIDATION_ERROR'), step),
        'Enter the six-digit code from the email.',
      );
      for (final error in [
        _error(502, 'UPSTREAM_ERROR'),
        _error(502, 'INVALID_SESSION'),
        _error(500),
      ]) {
        expect(
          emailChangeErrorMessage(error, step),
          'We could not confirm the code. Please try again.',
          reason: '${error.statusCode} ${error.code}',
        );
      }
    });
  });

  group('isStandardSessionToken', () {
    test('accepts a standard session', () {
      expect(
        isStandardSessionToken(_token({'session_purpose': 'standard'})),
        isTrue,
      );
    });

    test('rejects recovery and unclassified sessions', () {
      expect(
        isStandardSessionToken(_token({'session_purpose': 'recovery'})),
        isFalse,
      );
      expect(
        isStandardSessionToken(_token({'session_purpose': 'unclassified_otp'})),
        isFalse,
      );
    });

    test('treats a missing claim as standard', () {
      expect(isStandardSessionToken(_token({'sub': 'user-1'})), isTrue);
    });

    test('fails open when the token cannot be read', () {
      expect(isStandardSessionToken('not-a-jwt'), isTrue);
      expect(isStandardSessionToken('a.%%%.c'), isTrue);
      expect(
        isStandardSessionToken('a.${base64Url.encode(utf8.encode('[]'))}.c'),
        isTrue,
      );
      expect(
        isStandardSessionToken('a.${base64Url.encode(utf8.encode('nope'))}.c'),
        isTrue,
      );
    });
  });

  group('EmailChangeResult', () {
    test('failure carries the message, code, and status', () {
      const result = EmailChangeResult.failure(
        'Nope',
        errorCode: 'RATE_LIMITED',
        statusCode: 429,
      );
      expect(result.status, EmailChangeStatus.failure);
      expect(result.message, 'Nope');
      expect(result.errorCode, 'RATE_LIMITED');
      expect(result.statusCode, 429);
    });
  });
}
