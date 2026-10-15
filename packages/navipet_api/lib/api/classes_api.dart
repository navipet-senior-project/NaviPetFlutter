//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ClassesApi {
  ClassesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Delete one authenticated user class
  ///
  /// Permanently removes one class from the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  A `classId` that is not on the authenticated user's schedule returns 404.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] classId (required):
  Future<Response> classesClassIdDeleteWithHttpInfo(String classId,) async {
    // ignore: prefer_const_declarations
    final path = r'/classes/{classId}'
      .replaceAll('{classId}', classId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Delete one authenticated user class
  ///
  /// Permanently removes one class from the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  A `classId` that is not on the authenticated user's schedule returns 404.
  ///
  /// Parameters:
  ///
  /// * [String] classId (required):
  Future<Object?> classesClassIdDelete(String classId,) async {
    final response = await classesClassIdDeleteWithHttpInfo(classId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Object',) as Object;
    
    }
    return null;
  }

  /// Update one authenticated user class
  ///
  /// Changes one class on the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`.  Send only the fields being changed. An empty body returns 422.  ### Location  Omitting `building` leaves the stored location untouched.  Sending `building` resolves it again, the same way `POST /classes` does.  ---  Setting `isOnline: true` clears the stored coordinates.  Setting `isOnline: false` resolves `building` — the one sent, else the stored one. An empty building returns 422.  ### Time  `time` replaces both `startTime` and `endTime` and cannot be combined with either.  ---  Changing `weekdays`, `time`, `startTime`, `endTime`, or `courseCode` re-checks the whole class.  ---  The end time must stay later than the start time (422), and the class must not conflict with another class on the schedule (409).  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] classId (required):
  ///
  /// * [ClassesClassIdPatchRequest] classesClassIdPatchRequest (required):
  Future<Response> classesClassIdPatchWithHttpInfo(String classId, ClassesClassIdPatchRequest classesClassIdPatchRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/classes/{classId}'
      .replaceAll('{classId}', classId);

    // ignore: prefer_final_locals
    Object? postBody = classesClassIdPatchRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update one authenticated user class
  ///
  /// Changes one class on the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`.  Send only the fields being changed. An empty body returns 422.  ### Location  Omitting `building` leaves the stored location untouched.  Sending `building` resolves it again, the same way `POST /classes` does.  ---  Setting `isOnline: true` clears the stored coordinates.  Setting `isOnline: false` resolves `building` — the one sent, else the stored one. An empty building returns 422.  ### Time  `time` replaces both `startTime` and `endTime` and cannot be combined with either.  ---  Changing `weekdays`, `time`, `startTime`, `endTime`, or `courseCode` re-checks the whole class.  ---  The end time must stay later than the start time (422), and the class must not conflict with another class on the schedule (409).  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.
  ///
  /// Parameters:
  ///
  /// * [String] classId (required):
  ///
  /// * [ClassesClassIdPatchRequest] classesClassIdPatchRequest (required):
  Future<ClassesClassIdPatch200Response?> classesClassIdPatch(String classId, ClassesClassIdPatchRequest classesClassIdPatchRequest,) async {
    final response = await classesClassIdPatchWithHttpInfo(classId, classesClassIdPatchRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ClassesClassIdPatch200Response',) as ClassesClassIdPatch200Response;
    
    }
    return null;
  }

  /// List the authenticated user classes
  ///
  /// Returns every class on the authenticated user's schedule, oldest first.  Requires `Authorization: Bearer <access_token>`, using the `access_token` from `POST /auth/login`.  In Swagger UI, paste the token into the \"Authorize\" button; it is then sent with every request on this page.  A user with no classes gets an empty array.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> classesGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/classes';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// List the authenticated user classes
  ///
  /// Returns every class on the authenticated user's schedule, oldest first.  Requires `Authorization: Bearer <access_token>`, using the `access_token` from `POST /auth/login`.  In Swagger UI, paste the token into the \"Authorize\" button; it is then sent with every request on this page.  A user with no classes gets an empty array.
  Future<ClassesGet200Response?> classesGet() async {
    final response = await classesGetWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ClassesGet200Response',) as ClassesGet200Response;
    
    }
    return null;
  }

  /// Add a class to the authenticated user schedule
  ///
  /// Adds one class to the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. The example request body below works as sent.  ### Location  `building` accepts a CSULB building name or code, or a plain street address.  Either way the saved class gets a resolved display name and coordinates, used later for class-aware navigation. A building or address that cannot be found returns 404.  Set `isOnline: true` for an online class; `building` may then be omitted or empty.  An in-person class with no `building` returns 422.  ### Time  Send the time one of two ways: `time` as a CSULB range such as \"4-6:45PM\", or `startTime` with `endTime`.  ---  Sending both forms, neither form, or a time that cannot be read returns 422.  An end time that is not later than the start time returns 422.  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ClassesPostRequest] classesPostRequest (required):
  Future<Response> classesPostWithHttpInfo(ClassesPostRequest classesPostRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/classes';

    // ignore: prefer_final_locals
    Object? postBody = classesPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Add a class to the authenticated user schedule
  ///
  /// Adds one class to the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. The example request body below works as sent.  ### Location  `building` accepts a CSULB building name or code, or a plain street address.  Either way the saved class gets a resolved display name and coordinates, used later for class-aware navigation. A building or address that cannot be found returns 404.  Set `isOnline: true` for an online class; `building` may then be omitted or empty.  An in-person class with no `building` returns 422.  ### Time  Send the time one of two ways: `time` as a CSULB range such as \"4-6:45PM\", or `startTime` with `endTime`.  ---  Sending both forms, neither form, or a time that cannot be read returns 422.  An end time that is not later than the start time returns 422.  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.
  ///
  /// Parameters:
  ///
  /// * [ClassesPostRequest] classesPostRequest (required):
  Future<ClassesPost201Response?> classesPost(ClassesPostRequest classesPostRequest,) async {
    final response = await classesPostWithHttpInfo(classesPostRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ClassesPost201Response',) as ClassesPost201Response;
    
    }
    return null;
  }
}
