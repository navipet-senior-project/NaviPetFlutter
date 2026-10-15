//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RecentSearchesApi {
  RecentSearchesApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Clear all recent selected campus places
  ///
  /// Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> allRecentSearchesDeleteWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/all-recent-searches';

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

  /// Clear all recent selected campus places
  ///
  /// Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.
  Future<Object?> allRecentSearchesDelete() async {
    final response = await allRecentSearchesDeleteWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'Object',
      ) as Object;
    }
    return null;
  }

  /// Clear all recent selected campus places
  ///
  /// Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> recentSearchesDeleteWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/recent-searches';

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

  /// Clear all recent selected campus places
  ///
  /// Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.
  Future<Object?> recentSearchesDelete() async {
    final response = await recentSearchesDeleteWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'Object',
      ) as Object;
    }
    return null;
  }

  /// Get recent selected campus places
  ///
  /// Returns the authenticated user's saved places, most recently searched first.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own list.  Each entry carries the place fields plus a `searchedAt` timestamp.  `limit` defaults to 10 and is capped at 20.  A user with no history gets an empty array, not a 404.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] limit:
  Future<Response> recentSearchesGetWithHttpInfo({
    int? limit,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/recent-searches';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }

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

  /// Get recent selected campus places
  ///
  /// Returns the authenticated user's saved places, most recently searched first.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own list.  Each entry carries the place fields plus a `searchedAt` timestamp.  `limit` defaults to 10 and is capped at 20.  A user with no history gets an empty array, not a 404.
  ///
  /// Parameters:
  ///
  /// * [int] limit:
  Future<RecentSearchesGet200Response?> recentSearchesGet({
    int? limit,
  }) async {
    final response = await recentSearchesGetWithHttpInfo(
      limit: limit,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'RecentSearchesGet200Response',
      ) as RecentSearchesGet200Response;
    }
    return null;
  }

  /// Save a selected campus place
  ///
  /// Records that the authenticated user picked a campus place, so it appears in `GET /recent-searches`.  Requires `Authorization: Bearer <access_token>`. Each user can read and write only their own list.  ---  Send the `id` of a campus result from `GET /autocomplete` as `placeId`.  The place is looked up again on the server; the stored copy comes from the database, not from the request.  Saving a place that is already in the list refreshes its timestamp instead of adding a duplicate, so the call is safe to repeat.  A well-formed UUID with no matching place returns 404.  A temporary Mapbox result (`mapbox:` prefixed `id`) cannot be saved and returns 422.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [RecentSearchesPostRequest] recentSearchesPostRequest (required):
  Future<Response> recentSearchesPostWithHttpInfo(
    RecentSearchesPostRequest recentSearchesPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/recent-searches';

    // ignore: prefer_final_locals
    Object? postBody = recentSearchesPostRequest;

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

  /// Save a selected campus place
  ///
  /// Records that the authenticated user picked a campus place, so it appears in `GET /recent-searches`.  Requires `Authorization: Bearer <access_token>`. Each user can read and write only their own list.  ---  Send the `id` of a campus result from `GET /autocomplete` as `placeId`.  The place is looked up again on the server; the stored copy comes from the database, not from the request.  Saving a place that is already in the list refreshes its timestamp instead of adding a duplicate, so the call is safe to repeat.  A well-formed UUID with no matching place returns 404.  A temporary Mapbox result (`mapbox:` prefixed `id`) cannot be saved and returns 422.
  ///
  /// Parameters:
  ///
  /// * [RecentSearchesPostRequest] recentSearchesPostRequest (required):
  Future<RecentSearchesPost201Response?> recentSearchesPost(
    RecentSearchesPostRequest recentSearchesPostRequest,
  ) async {
    final response = await recentSearchesPostWithHttpInfo(
      recentSearchesPostRequest,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'RecentSearchesPost201Response',
      ) as RecentSearchesPost201Response;
    }
    return null;
  }
}
