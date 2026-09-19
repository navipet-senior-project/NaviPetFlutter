import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';
import 'campus_place.dart';
import 'navigation_models.dart';

abstract interface class CampusSearchGateway {
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  });

  Future<CampusPlace> place(String stableId);
}

class HttpCampusSearchGateway implements CampusSearchGateway {
  HttpCampusSearchGateway({
    required String baseUrl,
    AuthTokenProvider? auth,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final AuthTokenProvider? _auth;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<CampusPlace>> autocomplete(
    String query, {
    NavigationCoordinate? proximity,
    int limit = 10,
  }) async {
    final requestedLimit = limit.clamp(1, 10);
    final uri = Uri.parse('$baseUrl/autocomplete').replace(
      queryParameters: {
        'q': query.trim(),
        'limit': '$requestedLimit',
        if (proximity != null) 'latitude': '${proximity.latitude}',
        if (proximity != null) 'longitude': '${proximity.longitude}',
      },
    );
    final body = await _getJson(uri);
    final rawResults = body['results'];
    if (rawResults is! List) {
      throw const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus search returned an invalid response.',
      );
    }
    try {
      return rawResults
          .take(10)
          .map((value) => CampusPlace.fromJson(value as Map<String, dynamic>))
          .toList(growable: false);
    } on CampusSearchException {
      rethrow;
    } on Object {
      throw const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus search returned an invalid response.',
      );
    }
  }

  @override
  Future<CampusPlace> place(String stableId) async {
    final encodedId = Uri.encodeComponent(stableId);
    final body = await _getJson(Uri.parse('$baseUrl/places/$encodedId'));
    final rawPlace = body['place'];
    if (rawPlace is! Map<String, dynamic>) {
      throw const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus place details were unavailable.',
      );
    }
    return CampusPlace.fromJson(rawPlace);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    var response = await _send(uri, forceRefresh: false);
    if (response.statusCode == 401 && _auth != null) {
      response = await _send(uri, forceRefresh: true);
    }
    return _decode(response);
  }

  Future<http.Response> _send(Uri uri, {required bool forceRefresh}) async {
    final token = await _auth?.token(forceRefresh: forceRefresh);
    try {
      return await _client
          .get(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Campus search timed out.',
      );
    } on SocketException {
      throw const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Campus search is offline.',
      );
    } on http.ClientException {
      throw const CampusSearchException(
        failure: CampusSearchFailure.offline,
        message: 'Campus search is offline.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Converted to a typed API failure below.
    }
    if (response.statusCode == 401) {
      throw const CampusSearchException(
        failure: CampusSearchFailure.unauthorized,
        message: 'Sign in again to search campus.',
        statusCode: 401,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body?['error'];
      final errorJson = error is Map ? error : const <String, dynamic>{};
      throw CampusSearchException(
        failure: CampusSearchFailure.api,
        message:
            errorJson['message']?.toString() ??
            'Campus search failed (${response.statusCode}).',
        statusCode: response.statusCode,
        code: errorJson['code']?.toString(),
      );
    }
    if (body == null) {
      throw const CampusSearchException(
        failure: CampusSearchFailure.api,
        message: 'Campus search returned an invalid response.',
      );
    }
    return body;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
