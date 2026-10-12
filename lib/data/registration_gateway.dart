import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class RegistrationSuccess {
  const RegistrationSuccess({required this.message, required this.otpRequired});

  final String message;
  final bool otpRequired;
}

class RegistrationVerificationSuccess {
  const RegistrationVerificationSuccess({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class PasswordResetRequestSuccess {
  const PasswordResetRequestSuccess({required this.message});

  final String message;
}

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

abstract interface class RegistrationGateway {
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  });

  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  });

  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  });

  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  });

  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  });

  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  });
}

class HttpRegistrationGateway implements RegistrationGateway {
  HttpRegistrationGateway({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 45);

  final String baseUrl;
  final http.Client _client;

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) => _postForTokens(
    path: '/auth/login',
    body: {'email': email, 'password': password},
  );

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _post(
      path: '/auth/register',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role,
      },
    );
    final body = _tryDecode(response.body);
    return RegistrationSuccess(
      message:
          body?['message']?.toString() ??
          'Verification code sent. Check your inbox.',
      otpRequired: body?['otp_required'] == true,
    );
  }

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) => _verifyCode(email: email, code: code, type: 'register');

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) async {
    final response = await _post(
      path: '/auth/forgot-password',
      body: {'email': email},
    );
    final body = _tryDecode(response.body);
    return PasswordResetRequestSuccess(
      message:
          body?['message']?.toString() ??
          'Verification code sent. Check your inbox.',
    );
  }

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) => _verifyCode(email: email, code: code, type: 'recovery');

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _post(
      path: '/auth/reset-password',
      body: {'newPassword': newPassword, 'confirmPassword': confirmPassword},
      headers: {'Authorization': 'Bearer $accessToken'},
      expectedStatus: 204,
    );
  }

  Future<RegistrationVerificationSuccess> _verifyCode({
    required String email,
    required String code,
    required String type,
  }) => _postForTokens(
    path: '/auth/verify-otp',
    body: {'email': email, 'code': code, 'type': type},
  );

  Future<RegistrationVerificationSuccess> _postForTokens({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final response = await _post(path: path, body: body);
    final decoded = _tryDecode(response.body);
    final accessToken = decoded?['access_token']?.toString() ?? '';
    final refreshToken = decoded?['refresh_token']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const RegistrationException(
        message: 'The authentication service returned an invalid session.',
        statusCode: 502,
        code: 'INVALID_SESSION',
      );
    }
    return RegistrationVerificationSuccess(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<http.Response> _post({
    required String path,
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
    int expectedStatus = 200,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (response.statusCode != expectedStatus) throw _errorFrom(response);
      return response;
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
  }

  RegistrationException _errorFrom(http.Response response) {
    final error = _tryDecode(response.body)?['error'];
    if (error is Map) {
      return RegistrationException(
        message: error['message']?.toString() ?? 'Request failed.',
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
