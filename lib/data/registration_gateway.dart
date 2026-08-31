import 'dart:async';
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

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
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

/// Complete authentication contract exposed by the hosted NaviPet API.
abstract interface class BackendAuthGateway implements RegistrationGateway {
  Future<AuthTokens> login({required String email, required String password});

  Future<void> requestPasswordReset(String email);

  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
    required bool isPasswordRecovery,
  });

  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
  });
}

/// Real [RegistrationGateway] backed by `package:http`.
class HttpRegistrationGateway implements BackendAuthGateway {
  HttpRegistrationGateway({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  // Render services may need extra time for a cold start.
  static const _timeout = Duration(seconds: 45);

  final String baseUrl;
  final http.Client _client;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return _tokensFrom(response);
  }

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
    });
    final body = _tryDecode(response.body);
    return RegistrationSuccess(
      message:
          body?['message']?.toString() ??
          'Verification code sent. Check your inbox.',
      confirmationRequired: body?['otp_required'] == true,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  @override
  Future<AuthTokens> verifyOtp({
    required String email,
    required String code,
    required bool isPasswordRecovery,
  }) async {
    final response = await _post('/auth/verify-otp', {
      'email': email,
      'code': code,
      'type': isPasswordRecovery ? 'recovery' : 'register',
    });
    return _tokensFrom(response);
  }

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
  }) async {
    await _post(
      '/auth/reset-password',
      {'newPassword': newPassword, 'confirmPassword': newPassword},
      accessToken: accessToken,
      expectedStatus: 204,
    );
  }

  AuthTokens _tokensFrom(http.Response response) {
    final body = _tryDecode(response.body);
    final accessToken = body?['access_token']?.toString() ?? '';
    final refreshToken = body?['refresh_token']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const RegistrationException(
        message: 'The authentication service returned an invalid session.',
        statusCode: 502,
        code: 'INVALID_SESSION',
      );
    }
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
    int expectedStatus = 200,
  }) async {
    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$normalizedBaseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';

    late final http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw const RegistrationException(
        message: 'The server took too long to respond. Please try again.',
        statusCode: 408,
        code: 'REQUEST_TIMEOUT',
      );
    } on http.ClientException {
      throw const RegistrationException(
        message: 'Could not reach the NaviPet server. Please try again.',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    }

    if (response.statusCode != expectedStatus) throw _errorFrom(response);
    return response;
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
      message: 'The NaviPet server could not complete the request.',
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
