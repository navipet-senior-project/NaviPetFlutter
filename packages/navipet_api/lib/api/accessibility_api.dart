//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AccessibilityApi {
  AccessibilityApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get the accessibility preferences
  ///
  /// Returns the ten accessibility preferences of the authenticated user, grouped as on the Accessibility screen.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own preferences.  A user who has never changed a preference gets the defaults, not a 404: voice guidance and haptic turn alerts are on, everything else is off.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> profilesMeAccessibilityGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/profiles/me/accessibility';

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

  /// Get the accessibility preferences
  ///
  /// Returns the ten accessibility preferences of the authenticated user, grouped as on the Accessibility screen.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own preferences.  A user who has never changed a preference gets the defaults, not a 404: voice guidance and haptic turn alerts are on, everything else is off.
  Future<ProfilesMeAccessibilityGet200Response?> profilesMeAccessibilityGet() async {
    final response = await profilesMeAccessibilityGetWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ProfilesMeAccessibilityGet200Response',) as ProfilesMeAccessibilityGet200Response;
    
    }
    return null;
  }

  /// Update accessibility preferences
  ///
  /// Changes one or more accessibility preferences of the authenticated user and returns all ten.  Requires `Authorization: Bearer <access_token>`. A user can change only their own preferences.  Send only the toggles that changed, inside their group. Toggles left out keep their current value.  Every toggle is independent. Turning on accessible routes does not turn on avoid stairs or prefer elevators.  The request must change at least one toggle. An empty object, an empty group, an unknown key, or a non-boolean value returns 422.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ProfilesMeAccessibilityPatchRequest] profilesMeAccessibilityPatchRequest (required):
  Future<Response> profilesMeAccessibilityPatchWithHttpInfo(ProfilesMeAccessibilityPatchRequest profilesMeAccessibilityPatchRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/profiles/me/accessibility';

    // ignore: prefer_final_locals
    Object? postBody = profilesMeAccessibilityPatchRequest;

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

  /// Update accessibility preferences
  ///
  /// Changes one or more accessibility preferences of the authenticated user and returns all ten.  Requires `Authorization: Bearer <access_token>`. A user can change only their own preferences.  Send only the toggles that changed, inside their group. Toggles left out keep their current value.  Every toggle is independent. Turning on accessible routes does not turn on avoid stairs or prefer elevators.  The request must change at least one toggle. An empty object, an empty group, an unknown key, or a non-boolean value returns 422.
  ///
  /// Parameters:
  ///
  /// * [ProfilesMeAccessibilityPatchRequest] profilesMeAccessibilityPatchRequest (required):
  Future<ProfilesMeAccessibilityGet200Response?> profilesMeAccessibilityPatch(ProfilesMeAccessibilityPatchRequest profilesMeAccessibilityPatchRequest,) async {
    final response = await profilesMeAccessibilityPatchWithHttpInfo(profilesMeAccessibilityPatchRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ProfilesMeAccessibilityGet200Response',) as ProfilesMeAccessibilityGet200Response;
    
    }
    return null;
  }
}
