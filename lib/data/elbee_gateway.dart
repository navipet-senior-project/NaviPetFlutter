import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';
import 'elbee_reply.dart';

abstract interface class ElbeeGateway {
  /// [includeNextClass] is the per-request schedule consent flag.
  Future<ElbeeReply> ask(String question, {required bool includeNextClass});
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
    required bool includeNextClass,
  }) async {
    if (baseUrl.isEmpty) {
      return const ElbeeReply(status: ElbeeStatus.network);
    }
    final body = jsonEncode({
      'question': question,
      'includeNextClass': includeNextClass,
    });
    try {
      var response = await _post(body, forceRefresh: false);
      if (response.statusCode == 401) {
        response = await _post(body, forceRefresh: true);
      }
      Object? json;
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
      if (response.statusCode >= 500 && response.statusCode != 503) {
        return const ElbeeReply(status: ElbeeStatus.network);
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

  Future<http.Response> _post(String body, {required bool forceRefresh}) async {
    final token = await _auth.token(forceRefresh: forceRefresh);
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
