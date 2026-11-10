import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';
import 'elbee_reply.dart';

abstract interface class ElbeeGateway {
  /// [scheduleConsent] is this request's permission to read the next class.
  Future<ElbeeReply> ask(String question, {required bool scheduleConsent});
}

class HttpElbeeGateway implements ElbeeGateway {
  HttpElbeeGateway({
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
  Future<ElbeeReply> ask(
    String question, {
    required bool scheduleConsent,
  }) async {
    final trimmed = question.trim();
    if (baseUrl.isEmpty) {
      return const ElbeeReply(status: ElbeeStatus.network);
    }
    if (trimmed.isEmpty || trimmed.length > 500) {
      return const ElbeeReply(status: ElbeeStatus.rejected);
    }
    final body = jsonEncode({
      'question': trimmed,
      'scheduleConsent': scheduleConsent,
      'mode': 'ask',
    });
    try {
      var token = await _auth.token();
      if (scheduleConsent && (token == null || token.isEmpty)) {
        return const ElbeeReply(status: ElbeeStatus.signedOut);
      }
      var response = await _post(body, token: token);
      if (response.statusCode == 401) {
        token = await _auth.token(forceRefresh: true);
        if (scheduleConsent && (token == null || token.isEmpty)) {
          return const ElbeeReply(status: ElbeeStatus.signedOut);
        }
        response = await _post(body, token: token);
      }
      Object? json;
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
      return ElbeeReply.parse(response.statusCode, json);
    } on TimeoutException {
      return const ElbeeReply(status: ElbeeStatus.network);
    } on SocketException {
      return const ElbeeReply(status: ElbeeStatus.network);
    } on http.ClientException {
      return const ElbeeReply(status: ElbeeStatus.network);
    }
  }

  Future<http.Response> _post(String body, {required String? token}) async {
    return _client
        .post(
          Uri.parse('$baseUrl/elbee/ask'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(_timeout);
  }
}
