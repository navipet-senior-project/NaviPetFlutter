//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApiClient {
  ApiClient({
    this.basePath = 'http://localhost',
    this.authentication,
  });

  final String basePath;
  final Authentication? authentication;

  var _client = Client();
  final _defaultHeaderMap = <String, String>{};

  /// Returns the current HTTP [Client] instance to use in this class.
  ///
  /// The return value is guaranteed to never be null.
  Client get client => _client;

  /// Requests to use a new HTTP [Client] in this class.
  set client(Client newClient) {
    _client = newClient;
  }

  Map<String, String> get defaultHeaderMap => _defaultHeaderMap;

  void addDefaultHeader(String key, String value) {
    _defaultHeaderMap[key] = value;
  }

  // We don't use a Map<String, String> for queryParams.
  // If collectionFormat is 'multi', a key might appear multiple times.
  Future<Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType,
  ) async {
    await authentication?.applyToParams(queryParams, headerParams);

    headerParams.addAll(_defaultHeaderMap);
    if (contentType != null) {
      headerParams['Content-Type'] = contentType;
    }

    final urlEncodedQueryParams = queryParams.map((param) => '$param');
    final queryString = urlEncodedQueryParams.isNotEmpty
        ? '?${urlEncodedQueryParams.join('&')}'
        : '';
    final uri = Uri.parse('$basePath$path$queryString');

    try {
      // Special case for uploading a single file which isn't a 'multipart/form-data'.
      if (body is MultipartFile &&
          (contentType == null ||
              !contentType.toLowerCase().startsWith('multipart/form-data'))) {
        final request = StreamedRequest(method, uri);
        request.headers.addAll(headerParams);
        request.contentLength = body.length;
        body.finalize().listen(
              request.sink.add,
              onDone: request.sink.close,
              // ignore: avoid_types_on_closure_parameters
              onError: (Object error, StackTrace trace) => request.sink.close(),
              cancelOnError: true,
            );
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      if (body is MultipartRequest) {
        final request = MultipartRequest(method, uri);
        request.fields.addAll(body.fields);
        request.files.addAll(body.files);
        request.headers.addAll(body.headers);
        request.headers.addAll(headerParams);
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      final msgBody = contentType == 'application/x-www-form-urlencoded'
          ? formParams
          : await serializeAsync(body);
      final nullableHeaderParams = headerParams.isEmpty ? null : headerParams;

      switch (method) {
        case 'POST':
          return await _client.post(
            uri,
            headers: nullableHeaderParams,
            body: msgBody,
          );
        case 'PUT':
          return await _client.put(
            uri,
            headers: nullableHeaderParams,
            body: msgBody,
          );
        case 'DELETE':
          return await _client.delete(
            uri,
            headers: nullableHeaderParams,
            body: msgBody,
          );
        case 'PATCH':
          return await _client.patch(
            uri,
            headers: nullableHeaderParams,
            body: msgBody,
          );
        case 'HEAD':
          return await _client.head(
            uri,
            headers: nullableHeaderParams,
          );
        case 'GET':
          return await _client.get(
            uri,
            headers: nullableHeaderParams,
          );
      }
    } on SocketException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Socket operation failed: $method $path',
        error,
        trace,
      );
    } on TlsException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'TLS/SSL communication failed: $method $path',
        error,
        trace,
      );
    } on IOException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'I/O operation failed: $method $path',
        error,
        trace,
      );
    } on ClientException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'HTTP connection failed: $method $path',
        error,
        trace,
      );
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Exception occurred: $method $path',
        error,
        trace,
      );
    }

    throw ApiException(
      HttpStatus.badRequest,
      'Invalid HTTP operation: $method $path',
    );
  }

  Future<dynamic> deserializeAsync(
    String value,
    String targetType, {
    bool growable = false,
  }) async =>
      // ignore: deprecated_member_use_from_same_package
      deserialize(value, targetType, growable: growable);

  @Deprecated(
      'Scheduled for removal in OpenAPI Generator 6.x. Use deserializeAsync() instead.')
  dynamic deserialize(
    String value,
    String targetType, {
    bool growable = false,
  }) {
    // Remove all spaces. Necessary for regular expressions as well.
    targetType =
        targetType.replaceAll(' ', ''); // ignore: parameter_assignments

    // If the expected target type is String, nothing to do...
    return targetType == 'String'
        ? value
        : fromJson(json.decode(value), targetType, growable: growable);
  }

  // ignore: deprecated_member_use_from_same_package
  Future<String> serializeAsync(Object? value) async => serialize(value);

  @Deprecated(
      'Scheduled for removal in OpenAPI Generator 6.x. Use serializeAsync() instead.')
  String serialize(Object? value) => value == null ? '' : json.encode(value);

  /// Returns a native instance of an OpenAPI class matching the [specified type][targetType].
  static dynamic fromJson(
    dynamic value,
    String targetType, {
    bool growable = false,
  }) {
    try {
      switch (targetType) {
        case 'String':
          return value is String ? value : value.toString();
        case 'int':
          return value is int ? value : int.parse('$value');
        case 'double':
          return value is double ? value : double.parse('$value');
        case 'bool':
          if (value is bool) {
            return value;
          }
          final valueString = '$value'.toLowerCase();
          return valueString == 'true' || valueString == '1';
        case 'DateTime':
          return value is DateTime ? value : DateTime.tryParse(value);
        case 'AuthChangeEmailPost202Response':
          return AuthChangeEmailPost202Response.fromJson(value);
        case 'AuthChangeEmailPost401Response':
          return AuthChangeEmailPost401Response.fromJson(value);
        case 'AuthChangeEmailPost422Response':
          return AuthChangeEmailPost422Response.fromJson(value);
        case 'AuthChangeEmailPost429Response':
          return AuthChangeEmailPost429Response.fromJson(value);
        case 'AuthChangeEmailPostRequest':
          return AuthChangeEmailPostRequest.fromJson(value);
        case 'AuthForgotPasswordPost200Response':
          return AuthForgotPasswordPost200Response.fromJson(value);
        case 'AuthForgotPasswordPost404Response':
          return AuthForgotPasswordPost404Response.fromJson(value);
        case 'AuthForgotPasswordPost422Response':
          return AuthForgotPasswordPost422Response.fromJson(value);
        case 'AuthForgotPasswordPost429Response':
          return AuthForgotPasswordPost429Response.fromJson(value);
        case 'AuthForgotPasswordPost502Response':
          return AuthForgotPasswordPost502Response.fromJson(value);
        case 'AuthForgotPasswordPost503Response':
          return AuthForgotPasswordPost503Response.fromJson(value);
        case 'AuthForgotPasswordPostRequest':
          return AuthForgotPasswordPostRequest.fromJson(value);
        case 'AuthLoginPost200Response':
          return AuthLoginPost200Response.fromJson(value);
        case 'AuthLoginPost400Response':
          return AuthLoginPost400Response.fromJson(value);
        case 'AuthLoginPost400ResponseError':
          return AuthLoginPost400ResponseError.fromJson(value);
        case 'AuthLoginPost401Response':
          return AuthLoginPost401Response.fromJson(value);
        case 'AuthLoginPost403Response':
          return AuthLoginPost403Response.fromJson(value);
        case 'AuthLoginPost422Response':
          return AuthLoginPost422Response.fromJson(value);
        case 'AuthLoginPost429Response':
          return AuthLoginPost429Response.fromJson(value);
        case 'AuthLoginPost502Response':
          return AuthLoginPost502Response.fromJson(value);
        case 'AuthLoginPostRequest':
          return AuthLoginPostRequest.fromJson(value);
        case 'AuthLogoutAllPost404Response':
          return AuthLogoutAllPost404Response.fromJson(value);
        case 'AuthLogoutAllPost500Response':
          return AuthLogoutAllPost500Response.fromJson(value);
        case 'AuthLogoutPost401Response':
          return AuthLogoutPost401Response.fromJson(value);
        case 'AuthLogoutPost429Response':
          return AuthLogoutPost429Response.fromJson(value);
        case 'AuthLogoutPost500Response':
          return AuthLogoutPost500Response.fromJson(value);
        case 'AuthLogoutPost503Response':
          return AuthLogoutPost503Response.fromJson(value);
        case 'AuthMeGet200Response':
          return AuthMeGet200Response.fromJson(value);
        case 'AuthMeGet200ResponseUser':
          return AuthMeGet200ResponseUser.fromJson(value);
        case 'AuthMeGet403Response':
          return AuthMeGet403Response.fromJson(value);
        case 'AuthMeGet500Response':
          return AuthMeGet500Response.fromJson(value);
        case 'AuthMeGet503Response':
          return AuthMeGet503Response.fromJson(value);
        case 'AuthRefreshPost401Response':
          return AuthRefreshPost401Response.fromJson(value);
        case 'AuthRefreshPost422Response':
          return AuthRefreshPost422Response.fromJson(value);
        case 'AuthRefreshPost429Response':
          return AuthRefreshPost429Response.fromJson(value);
        case 'AuthRefreshPost500Response':
          return AuthRefreshPost500Response.fromJson(value);
        case 'AuthRefreshPostRequest':
          return AuthRefreshPostRequest.fromJson(value);
        case 'AuthRegisterPost200Response':
          return AuthRegisterPost200Response.fromJson(value);
        case 'AuthRegisterPost409Response':
          return AuthRegisterPost409Response.fromJson(value);
        case 'AuthRegisterPost422Response':
          return AuthRegisterPost422Response.fromJson(value);
        case 'AuthRegisterPost429Response':
          return AuthRegisterPost429Response.fromJson(value);
        case 'AuthRegisterPost500Response':
          return AuthRegisterPost500Response.fromJson(value);
        case 'AuthRegisterPostRequest':
          return AuthRegisterPostRequest.fromJson(value);
        case 'AuthResetPasswordPost401Response':
          return AuthResetPasswordPost401Response.fromJson(value);
        case 'AuthResetPasswordPost422Response':
          return AuthResetPasswordPost422Response.fromJson(value);
        case 'AuthResetPasswordPost500Response':
          return AuthResetPasswordPost500Response.fromJson(value);
        case 'AuthResetPasswordPostRequest':
          return AuthResetPasswordPostRequest.fromJson(value);
        case 'AuthVerifyOtpPost200Response':
          return AuthVerifyOtpPost200Response.fromJson(value);
        case 'AuthVerifyOtpPost401Response':
          return AuthVerifyOtpPost401Response.fromJson(value);
        case 'AuthVerifyOtpPost422Response':
          return AuthVerifyOtpPost422Response.fromJson(value);
        case 'AuthVerifyOtpPost429Response':
          return AuthVerifyOtpPost429Response.fromJson(value);
        case 'AuthVerifyOtpPostRequest':
          return AuthVerifyOtpPostRequest.fromJson(value);
        case 'AutocompleteGet200Response':
          return AutocompleteGet200Response.fromJson(value);
        case 'AutocompleteGet200ResponseProximity':
          return AutocompleteGet200ResponseProximity.fromJson(value);
        case 'AutocompleteGet200ResponseResultsInner':
          return AutocompleteGet200ResponseResultsInner.fromJson(value);
        case 'AutocompleteGet200ResponseResultsInnerNavigation':
          return AutocompleteGet200ResponseResultsInnerNavigation.fromJson(
              value);
        case 'AutocompleteGet200ResponseResultsInnerNavigationOutdoorDestination':
          return AutocompleteGet200ResponseResultsInnerNavigationOutdoorDestination
              .fromJson(value);
        case 'AutocompleteGet422Response':
          return AutocompleteGet422Response.fromJson(value);
        case 'AutocompleteGet502Response':
          return AutocompleteGet502Response.fromJson(value);
        case 'BuildingsBuildingCodeRoomsGet200Response':
          return BuildingsBuildingCodeRoomsGet200Response.fromJson(value);
        case 'BuildingsBuildingCodeRoomsGet200ResponseBuilding':
          return BuildingsBuildingCodeRoomsGet200ResponseBuilding.fromJson(
              value);
        case 'BuildingsBuildingCodeRoomsGet404Response':
          return BuildingsBuildingCodeRoomsGet404Response.fromJson(value);
        case 'BuildingsBuildingCodeRoomsGet422Response':
          return BuildingsBuildingCodeRoomsGet422Response.fromJson(value);
        case 'ClassResponse':
          return ClassResponse.fromJson(value);
        case 'ClassesClassIdDelete404Response':
          return ClassesClassIdDelete404Response.fromJson(value);
        case 'ClassesClassIdPatch200Response':
          return ClassesClassIdPatch200Response.fromJson(value);
        case 'ClassesClassIdPatch404Response':
          return ClassesClassIdPatch404Response.fromJson(value);
        case 'ClassesClassIdPatchRequest':
          return ClassesClassIdPatchRequest.fromJson(value);
        case 'ClassesGet200Response':
          return ClassesGet200Response.fromJson(value);
        case 'ClassesGet502Response':
          return ClassesGet502Response.fromJson(value);
        case 'ClassesPost201Response':
          return ClassesPost201Response.fromJson(value);
        case 'ClassesPost201ResponseClass':
          return ClassesPost201ResponseClass.fromJson(value);
        case 'ClassesPost404Response':
          return ClassesPost404Response.fromJson(value);
        case 'ClassesPost409Response':
          return ClassesPost409Response.fromJson(value);
        case 'ClassesPost409ResponseError':
          return ClassesPost409ResponseError.fromJson(value);
        case 'ClassesPost409ResponseErrorConflictsInner':
          return ClassesPost409ResponseErrorConflictsInner.fromJson(value);
        case 'ClassesPostRequest':
          return ClassesPostRequest.fromJson(value);
        case 'HealthGet200Response':
          return HealthGet200Response.fromJson(value);
        case 'PlacesPlaceIdGet200Response':
          return PlacesPlaceIdGet200Response.fromJson(value);
        case 'PlacesPlaceIdGet404Response':
          return PlacesPlaceIdGet404Response.fromJson(value);
        case 'PlacesPlaceIdGet422Response':
          return PlacesPlaceIdGet422Response.fromJson(value);
        case 'ProfilesMeAccessibilityGet200Response':
          return ProfilesMeAccessibilityGet200Response.fromJson(value);
        case 'ProfilesMeAccessibilityGet200ResponseAccessibility':
          return ProfilesMeAccessibilityGet200ResponseAccessibility.fromJson(
              value);
        case 'ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance':
          return ProfilesMeAccessibilityGet200ResponseAccessibilityGuidance
              .fromJson(value);
        case 'ProfilesMeAccessibilityGet200ResponseAccessibilityMobility':
          return ProfilesMeAccessibilityGet200ResponseAccessibilityMobility
              .fromJson(value);
        case 'ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals':
          return ProfilesMeAccessibilityGet200ResponseAccessibilityVisuals
              .fromJson(value);
        case 'ProfilesMeAccessibilityGet502Response':
          return ProfilesMeAccessibilityGet502Response.fromJson(value);
        case 'ProfilesMeAccessibilityPatch400Response':
          return ProfilesMeAccessibilityPatch400Response.fromJson(value);
        case 'ProfilesMeAccessibilityPatchRequest':
          return ProfilesMeAccessibilityPatchRequest.fromJson(value);
        case 'ProfilesMeAccessibilityPatchRequestGuidance':
          return ProfilesMeAccessibilityPatchRequestGuidance.fromJson(value);
        case 'ProfilesMeAccessibilityPatchRequestMobility':
          return ProfilesMeAccessibilityPatchRequestMobility.fromJson(value);
        case 'ProfilesMeAccessibilityPatchRequestVisuals':
          return ProfilesMeAccessibilityPatchRequestVisuals.fromJson(value);
        case 'ProfilesMeAvatarPost200Response':
          return ProfilesMeAvatarPost200Response.fromJson(value);
        case 'ProfilesMeAvatarPost400Response':
          return ProfilesMeAvatarPost400Response.fromJson(value);
        case 'ProfilesMeAvatarPost413Response':
          return ProfilesMeAvatarPost413Response.fromJson(value);
        case 'ProfilesMeAvatarPost415Response':
          return ProfilesMeAvatarPost415Response.fromJson(value);
        case 'ProfilesMeAvatarUploadIdDelete404Response':
          return ProfilesMeAvatarUploadIdDelete404Response.fromJson(value);
        case 'ProfilesMeAvatarUploadIdDelete422Response':
          return ProfilesMeAvatarUploadIdDelete422Response.fromJson(value);
        case 'ProfilesMeAvatarUploadIdDelete502Response':
          return ProfilesMeAvatarUploadIdDelete502Response.fromJson(value);
        case 'ProfilesMeAvatarUploadIdDelete503Response':
          return ProfilesMeAvatarUploadIdDelete503Response.fromJson(value);
        case 'ProfilesMeGet200Response':
          return ProfilesMeGet200Response.fromJson(value);
        case 'ProfilesMeGet200ResponseProfile':
          return ProfilesMeGet200ResponseProfile.fromJson(value);
        case 'ProfilesMeGet404Response':
          return ProfilesMeGet404Response.fromJson(value);
        case 'ProfilesMePatch404Response':
          return ProfilesMePatch404Response.fromJson(value);
        case 'ProfilesMePatch422Response':
          return ProfilesMePatch422Response.fromJson(value);
        case 'ProfilesMePatchRequest':
          return ProfilesMePatchRequest.fromJson(value);
        case 'RecentSearchesGet200Response':
          return RecentSearchesGet200Response.fromJson(value);
        case 'RecentSearchesGet200ResponseRecentSearchesInner':
          return RecentSearchesGet200ResponseRecentSearchesInner.fromJson(
              value);
        case 'RecentSearchesGet401Response':
          return RecentSearchesGet401Response.fromJson(value);
        case 'RecentSearchesGet422Response':
          return RecentSearchesGet422Response.fromJson(value);
        case 'RecentSearchesGet502Response':
          return RecentSearchesGet502Response.fromJson(value);
        case 'RecentSearchesPost201Response':
          return RecentSearchesPost201Response.fromJson(value);
        case 'RecentSearchesPost404Response':
          return RecentSearchesPost404Response.fromJson(value);
        case 'RecentSearchesPostRequest':
          return RecentSearchesPostRequest.fromJson(value);
        default:
          dynamic match;
          if (value is List &&
              (match = _regList.firstMatch(targetType)?.group(1)) != null) {
            return value
                .map<dynamic>((dynamic v) => fromJson(
                      v,
                      match,
                      growable: growable,
                    ))
                .toList(growable: growable);
          }
          if (value is Set &&
              (match = _regSet.firstMatch(targetType)?.group(1)) != null) {
            return value
                .map<dynamic>((dynamic v) => fromJson(
                      v,
                      match,
                      growable: growable,
                    ))
                .toSet();
          }
          if (value is Map &&
              (match = _regMap.firstMatch(targetType)?.group(1)) != null) {
            return Map<String, dynamic>.fromIterables(
              value.keys.cast<String>(),
              value.values.map<dynamic>((dynamic v) => fromJson(
                    v,
                    match,
                    growable: growable,
                  )),
            );
          }
      }
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.internalServerError,
        'Exception during deserialization.',
        error,
        trace,
      );
    }
    throw ApiException(
      HttpStatus.internalServerError,
      'Could not find a suitable class for deserialization',
    );
  }
}

/// Primarily intended for use in an isolate.
class DeserializationMessage {
  const DeserializationMessage({
    required this.json,
    required this.targetType,
    this.growable = false,
  });

  /// The JSON value to deserialize.
  final String json;

  /// Target type to deserialize to.
  final String targetType;

  /// Whether to make deserialized lists or maps growable.
  final bool growable;
}

/// Primarily intended for use in an isolate.
Future<dynamic> decodeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String' ? message.json : json.decode(message.json);
}

/// Primarily intended for use in an isolate.
Future<dynamic> deserializeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
      ? message.json
      : ApiClient.fromJson(
          json.decode(message.json),
          targetType,
          growable: message.growable,
        );
}

/// Primarily intended for use in an isolate.
Future<String> serializeAsync(Object? value) async =>
    value == null ? '' : json.encode(value);
