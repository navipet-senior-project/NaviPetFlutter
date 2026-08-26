import 'dart:convert';

import 'package:http/http.dart' as http;

/// Successful `POST /auth/register` response from the NaviPet backend.
///
/// The backend never returns tokens from this endpoint — registration always
/// requires confirming an email before a session exists.
class RegistrationSuccess {
  const RegistrationSuccess({
    required this.message,
    required this.confirmationRequired,
  });

  final String message;
  final bool confirmationRequired;
}

/// Thrown when the backend rejects a registration attempt.
///
/// Carries whatever the standard `{ "error": { code, message, requestId } }`
/// envelope provided, or a generic message when the response body could not
/// be parsed as that envelope.
class RegistrationException implements Exception {
  const RegistrationException({
    required this.message,
    required this.statusCode,
    this.code,
    this.requestId,
  });

  final String message;
  final int statusCode;
  final String? code;
  final String? requestId;

  @override
  String toString() =>
      'RegistrationException(statusCode: $statusCode, code: $code, '
      'message: $message)';
}

/// Registers a new NaviPet account against the backend's confirmation-email
/// signup flow. Abstracted behind an interface so tests can inject a fake.
abstract interface class RegistrationGateway {
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });
}

/// Real [RegistrationGateway] backed by `package:http`.
class HttpRegistrationGateway implements RegistrationGateway {
  HttpRegistrationGateway({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final http.Client _client;

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'password': password,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final body = _tryDecode(response.body);
      final message =
          body?['message']?.toString() ??
          'Confirmation email sent. Check your inbox.';
      final confirmationRequired = body?['confirmation_required'] == true;
      return RegistrationSuccess(
        message: message,
        confirmationRequired: confirmationRequired,
      );
    }

    throw _errorFrom(response);
  }

  RegistrationException _errorFrom(http.Response response) {
    final body = _tryDecode(response.body);
    final error = body?['error'];
    if (error is Map) {
      return RegistrationException(
        message: error['message']?.toString() ?? 'Registration failed.',
        statusCode: response.statusCode,
        code: error['code']?.toString(),
        requestId: error['requestId']?.toString(),
      );
    }
    return RegistrationException(
      message: 'Registration failed. Please try again.',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
