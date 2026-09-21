import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'course_class.dart';

class ClassesApiException implements Exception {
  const ClassesApiException({required this.message, required this.statusCode});
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

abstract interface class ClassesGateway {
  Future<List<CourseClass>> listClasses(String accessToken);
  Future<CourseClass> createClass({required String accessToken, required CourseClassInput input});
  Future<CourseClass> updateClass({required String accessToken, required String classId, required CourseClassInput input});
  Future<void> deleteClass({required String accessToken, required String classId});
}

class HttpClassesGateway implements ClassesGateway {
  HttpClassesGateway({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''), _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  @override
  Future<List<CourseClass>> listClasses(String accessToken) async {
    final response = await _request('GET', '/classes', accessToken: accessToken);
    final rows = _decode(response)?['classes'];
    if (rows is! List) throw _malformed(response.statusCode);
    return rows.whereType<Map>().map((row) => CourseClass.fromJson(_normalize(row))).toList();
  }

  @override
  Future<CourseClass> createClass({required String accessToken, required CourseClassInput input}) async {
    final response = await _request('POST', '/classes', accessToken: accessToken, body: input.toApiJson(), expectedStatus: 201);
    return _classFromMutation(response);
  }

  @override
  Future<CourseClass> updateClass({required String accessToken, required String classId, required CourseClassInput input}) async {
    final response = await _request('PATCH', '/classes/$classId', accessToken: accessToken, body: input.toApiJson());
    return _classFromMutation(response);
  }

  @override
  Future<void> deleteClass({required String accessToken, required String classId}) async {
    await _request('DELETE', '/classes/$classId', accessToken: accessToken, expectedStatus: 204);
  }

  Future<http.Response> _request(String method, String path, {required String accessToken, Map<String, dynamic>? body, int expectedStatus = 200}) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'});
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await _client.send(request).then(http.Response.fromStream).timeout(_timeout);
      if (response.statusCode != expectedStatus) throw _errorFrom(response);
      return response;
    } on TimeoutException {
      throw const ClassesApiException(message: 'The server took too long to respond. Please try again.', statusCode: 408);
    } on http.ClientException {
      throw const ClassesApiException(message: 'Could not reach the NaviPet server. Please try again.', statusCode: 0);
    }
  }

  CourseClass _classFromMutation(http.Response response) {
    final row = _decode(response)?['class'];
    if (row is! Map) throw _malformed(response.statusCode);
    return CourseClass.fromJson(_normalize(row));
  }

  ClassesApiException _errorFrom(http.Response response) {
    final error = _decode(response)?['error'];
    return ClassesApiException(
      message: error is Map && error['message'] != null ? error['message'].toString() : 'The NaviPet server could not complete the class request.',
      statusCode: response.statusCode,
    );
  }

  ClassesApiException _malformed(int statusCode) => ClassesApiException(message: 'The NaviPet server returned an invalid class response.', statusCode: statusCode);

  Map<String, dynamic>? _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _normalize(Map row) => {for (final entry in row.entries) entry.key.toString(): entry.value};
}
