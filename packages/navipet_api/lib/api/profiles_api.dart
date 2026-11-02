//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfilesApi {
  ProfilesApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get the authenticated user profile
  ///
  /// Returns the display name, email, role, and avatar of the authenticated user, as shown on the profile screen.  Requires `Authorization: Bearer <access_token>`.  `avatarUrl` is a temporary signed URL that expires after about one hour, so fetch the profile again rather than caching the URL.  `avatarUrl` is `null` when no avatar can be served; show a local placeholder instead.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> profilesMeGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/profiles/me';

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

  /// Get the authenticated user profile
  ///
  /// Returns the display name, email, role, and avatar of the authenticated user, as shown on the profile screen.  Requires `Authorization: Bearer <access_token>`.  `avatarUrl` is a temporary signed URL that expires after about one hour, so fetch the profile again rather than caching the URL.  `avatarUrl` is `null` when no avatar can be served; show a local placeholder instead.
  Future<ProfilesMeGet200Response?> profilesMeGet() async {
    final response = await profilesMeGetWithHttpInfo();
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
        'ProfilesMeGet200Response',
      ) as ProfilesMeGet200Response;
    }
    return null;
  }

  /// Update the authenticated user profile
  ///
  /// Updates the profile of the authenticated user and returns the saved profile.  Requires `Authorization: Bearer <access_token>`.  Send at least one field. Omitted fields keep their current values. Use JSON when changing text fields only. Use multipart form data when including an avatar file; send text fields as ordinary form fields and the image in a field named `avatar`.  `displayName` is trimmed and cannot be blank. To change the email, use `POST /auth/change-email`; email is deliberately not editable through this endpoint.  Avatar images must be JPEG, PNG, or WebP and no larger than 5 MB. The server stores a newly selected avatar only when this request saves successfully.  The returned `avatarUrl` is a temporary signed URL that expires after about one hour.  In Swagger UI, delete the fields you do not want to change from the example body before executing.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ProfilesMePatchRequest] profilesMePatchRequest (required):
  Future<Response> profilesMePatchWithHttpInfo(
    ProfilesMePatchRequest profilesMePatchRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/profiles/me';

    // ignore: prefer_final_locals
    Object? postBody = profilesMePatchRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json', 'multipart/form-data'];

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

  /// Update the authenticated user profile
  ///
  /// Updates the profile of the authenticated user and returns the saved profile.  Requires `Authorization: Bearer <access_token>`.  Send at least one field. Omitted fields keep their current values. Use JSON when changing text fields only. Use multipart form data when including an avatar file; send text fields as ordinary form fields and the image in a field named `avatar`.  `displayName` is trimmed and cannot be blank. To change the email, use `POST /auth/change-email`; email is deliberately not editable through this endpoint.  Avatar images must be JPEG, PNG, or WebP and no larger than 5 MB. The server stores a newly selected avatar only when this request saves successfully.  The returned `avatarUrl` is a temporary signed URL that expires after about one hour.  In Swagger UI, delete the fields you do not want to change from the example body before executing.
  ///
  /// Parameters:
  ///
  /// * [ProfilesMePatchRequest] profilesMePatchRequest (required):
  Future<ProfilesMeGet200Response?> profilesMePatch(
    ProfilesMePatchRequest profilesMePatchRequest,
  ) async {
    final response = await profilesMePatchWithHttpInfo(
      profilesMePatchRequest,
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
        'ProfilesMeGet200Response',
      ) as ProfilesMeGet200Response;
    }
    return null;
  }
}
