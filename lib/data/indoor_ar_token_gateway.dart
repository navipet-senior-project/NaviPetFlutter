import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';
import 'indoor_ar_contract.dart';

/// Why a token could not be had. Carries no token and no response body, so it
/// is safe to log.
class IndoorArTokenException implements Exception {
  const IndoorArTokenException(this.statusCode);

  /// The HTTP status, or `0` when no usable response arrived (offline,
  /// timeout, malformed body, expired token).
  final int statusCode;

  @override
  String toString() => 'IndoorArTokenException($statusCode)';
}

abstract interface class IndoorArTokenGateway {
  /// Mints a short-lived MultiSet token for on-device localisation.
  Future<IndoorArToken> fetch();
}

/// `POST /indoor/ar-token`. Hand-written: the generated client predates the
/// route. The token is never logged or stored.
class HttpIndoorArTokenGateway implements IndoorArTokenGateway {
  HttpIndoorArTokenGateway({
    required String baseUrl,
    required AuthTokenProvider auth,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final AuthTokenProvider _auth;
  final http.Client _client;

  @override
  Future<IndoorArToken> fetch() async {
    var response = await _post(forceRefresh: false);
    if (response.statusCode == 401) {
      response = await _post(forceRefresh: true);
    }
    if (response.statusCode != 200) {
      throw IndoorArTokenException(response.statusCode);
    }
    return _parse(response);
  }

  Future<http.Response> _post({required bool forceRefresh}) async {
    final session = await _auth.token(forceRefresh: forceRefresh);
    if (session == null || session.isEmpty) {
      throw const IndoorArTokenException(401);
    }
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl/indoor/ar-token'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $session',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const IndoorArTokenException(0);
    } on SocketException {
      throw const IndoorArTokenException(0);
    } on http.ClientException {
      throw const IndoorArTokenException(0);
    }
  }

  IndoorArToken _parse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final token = body['token'];
        final expiresOn = body['expiresOn'];
        final expiry = expiresOn is String
            ? DateTime.tryParse(expiresOn)
            : null;
        if (token is String && token.isNotEmpty && expiry != null) {
          return IndoorArToken(token: token, expiresOn: expiry.toUtc());
        }
      }
    } on FormatException {
      // Falls through to the shared malformed-body failure.
    }
    throw const IndoorArTokenException(0);
  }
}
