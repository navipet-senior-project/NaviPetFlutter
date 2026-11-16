import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token_provider.dart';

class ProfileApiException implements Exception {
  const ProfileApiException({required this.message, required this.statusCode});
  final String message;

  /// The HTTP status, `0` when the server was unreachable, or `408` on a
  /// client-side timeout.
  final int statusCode;
  @override
  String toString() => message;
}

/// The profile fields the backend serves from `/profiles/me`.
class RemoteProfile {
  const RemoteProfile({
    required this.displayName,
    this.email,
    this.role,
    this.avatarUrl,
  });

  final String displayName;
  final String? email;
  final String? role;

  /// A signed URL that expires after about an hour, or `null` when the
  /// backend cannot serve an avatar.
  final String? avatarUrl;
}

abstract interface class ProfileGateway {
  Future<RemoteProfile> fetchProfile();

  /// Saves the given fields; omitted (`null`) fields keep their values.
  /// [avatarBytes] (JPEG, PNG or WebP, at most 5 MB) becomes the avatar in
  /// the same request.
  Future<RemoteProfile> updateProfile({
    String? displayName,
    String? role,
    List<int>? avatarBytes,
  });
}

class HttpProfileGateway implements ProfileGateway {
  HttpProfileGateway({
    required String baseUrl,
    required AuthTokenProvider auth,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       // ignore: prefer_initializing_formals
       _auth = auth,
       _client = client ?? http.Client();

  static const avatarFieldName = 'avatar';
  static const _timeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(seconds: 60);

  final String baseUrl;
  final AuthTokenProvider _auth;
  final http.Client _client;

  @override
  Future<RemoteProfile> fetchProfile() async {
    final response = await _send(
      () => http.Request('GET', _uri('/profiles/me')),
    );
    return _profileFrom(response);
  }

  @override
  Future<RemoteProfile> updateProfile({
    String? displayName,
    String? role,
    List<int>? avatarBytes,
  }) async {
    final response = await _send(() {
      if (avatarBytes == null) {
        return http.Request('PATCH', _uri('/profiles/me'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'displayName': ?displayName, 'role': ?role});
      }
      // fromBytes rather than fromPath: it works on every platform, and a
      // cropped avatar is small enough to hold in memory.
      return http.MultipartRequest('PATCH', _uri('/profiles/me'))
        ..fields.addAll({'displayName': ?displayName, 'role': ?role})
        ..files.add(
          http.MultipartFile.fromBytes(
            avatarFieldName,
            avatarBytes,
            filename: 'avatar.png',
          ),
        );
    }, timeout: avatarBytes == null ? _timeout : _uploadTimeout);
    return _profileFrom(response);
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Sends a request built by [build], rebuilding it once with a refreshed
  /// token after a 401 (a sent request cannot be re-sent).
  Future<http.Response> _send(
    http.BaseRequest Function() build, {
    int expectedStatus = 200,
    int? alsoAccept,
    Duration timeout = _timeout,
  }) async {
    var response = await _attempt(build, forceRefresh: false, timeout: timeout);
    if (response.statusCode == 401) {
      response = await _attempt(build, forceRefresh: true, timeout: timeout);
    }
    final status = response.statusCode;
    if (status != expectedStatus && status != alsoAccept) {
      throw _errorFrom(response);
    }
    return response;
  }

  Future<http.Response> _attempt(
    http.BaseRequest Function() build, {
    required bool forceRefresh,
    required Duration timeout,
  }) async {
    final token = await _auth.token(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw const ProfileApiException(
        message: 'Sign in to update your profile.',
        statusCode: 401,
      );
    }
    final request = build()
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const ProfileApiException(
        message: 'The server took too long to respond. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException {
      throw const ProfileApiException(
        message: 'Could not reach the NaviPet server. Please try again.',
        statusCode: 0,
      );
    }
  }

  RemoteProfile _profileFrom(http.Response response) {
    final profile = _decode(response)?['profile'];
    if (profile is! Map) throw _malformed(response.statusCode);
    final avatarUrl = profile['avatarUrl'];
    return RemoteProfile(
      displayName: (profile['displayName'] ?? '').toString(),
      email: profile['email']?.toString(),
      role: profile['role']?.toString(),
      avatarUrl: avatarUrl is String && avatarUrl.isNotEmpty ? avatarUrl : null,
    );
  }

  ProfileApiException _errorFrom(http.Response response) {
    final error = _decode(response)?['error'];
    return ProfileApiException(
      message: error is Map && error['message'] != null
          ? error['message'].toString()
          : 'The NaviPet server could not complete the profile request.',
      statusCode: response.statusCode,
    );
  }

  ProfileApiException _malformed(int statusCode) => ProfileApiException(
    message: 'The NaviPet server returned an invalid profile response.',
    statusCode: statusCode,
  );

  Map<String, dynamic>? _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
