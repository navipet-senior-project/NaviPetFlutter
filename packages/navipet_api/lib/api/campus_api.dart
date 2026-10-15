//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CampusApi {
  CampusApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Autocomplete campus destinations
  ///
  /// Searches active, searchable CSULB campus destinations that match `q`.  Requires `Authorization: Bearer <access_token>`.  `q` must contain at least two meaningful characters, otherwise the request returns 422.  `limit` defaults to 10 and is capped at 20.  `latitude` and `longitude` are optional but must be sent together.  ---  ### Proximity search  These phrases search for the nearest matching places instead of matching by name: \"nearest restroom\", \"food near me\", \"nearest parking\", \"closest bus stop\", \"coffee near me\".  They require `latitude` and `longitude`; without them the request returns 422.  ---  Only places within 2000 meters are returned, each with `distanceMeters`, and the response gains a `proximity` object.  ---  ### Mapbox fallback  When an ordinary search finds no campus destination with outdoor coordinates, a temporary Mapbox result may be returned instead. Proximity searches never do this.  A Mapbox result has `external: true` and an `id` starting with `mapbox:`.  ---  It is not stored, so that `id` cannot be used with `GET /places/{placeId}` or `POST /recent-searches`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  ///
  /// * [int] limit:
  ///
  /// * [num] latitude:
  ///
  /// * [num] longitude:
  Future<Response> autocompleteGetWithHttpInfo(
    String q, {
    int? limit,
    num? latitude,
    num? longitude,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/autocomplete';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'q', q));
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (latitude != null) {
      queryParams.addAll(_queryParams('', 'latitude', latitude));
    }
    if (longitude != null) {
      queryParams.addAll(_queryParams('', 'longitude', longitude));
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

  /// Autocomplete campus destinations
  ///
  /// Searches active, searchable CSULB campus destinations that match `q`.  Requires `Authorization: Bearer <access_token>`.  `q` must contain at least two meaningful characters, otherwise the request returns 422.  `limit` defaults to 10 and is capped at 20.  `latitude` and `longitude` are optional but must be sent together.  ---  ### Proximity search  These phrases search for the nearest matching places instead of matching by name: \"nearest restroom\", \"food near me\", \"nearest parking\", \"closest bus stop\", \"coffee near me\".  They require `latitude` and `longitude`; without them the request returns 422.  ---  Only places within 2000 meters are returned, each with `distanceMeters`, and the response gains a `proximity` object.  ---  ### Mapbox fallback  When an ordinary search finds no campus destination with outdoor coordinates, a temporary Mapbox result may be returned instead. Proximity searches never do this.  A Mapbox result has `external: true` and an `id` starting with `mapbox:`.  ---  It is not stored, so that `id` cannot be used with `GET /places/{placeId}` or `POST /recent-searches`.
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  ///
  /// * [int] limit:
  ///
  /// * [num] latitude:
  ///
  /// * [num] longitude:
  Future<AutocompleteGet200Response?> autocompleteGet(
    String q, {
    int? limit,
    num? latitude,
    num? longitude,
  }) async {
    final response = await autocompleteGetWithHttpInfo(
      q,
      limit: limit,
      latitude: latitude,
      longitude: longitude,
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
        'AutocompleteGet200Response',
      ) as AutocompleteGet200Response;
    }
    return null;
  }

  /// Search verified rooms in a building
  ///
  /// Searches the rooms inside one building, best match for `q` first.  Requires `Authorization: Bearer <access_token>`.  `buildingCode` is the campus building code, for example \"ECS\". It is matched case-insensitively.  ---  `q` must contain at least two meaningful characters. Whitespace inside it is ignored, so \"101\" and \"1 01\" match the same rooms.  `limit` defaults to 10 and is capped at 20.  Only active, searchable rooms are returned — never buildings, entrances, or other destination types.  A building code that does not resolve to an active, searchable building returns 404.  `latitude` and `longitude` are accepted but ignored here.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  ///
  /// * [String] buildingCode (required):
  ///
  /// * [int] limit:
  ///
  /// * [num] latitude:
  ///
  /// * [num] longitude:
  Future<Response> buildingsBuildingCodeRoomsGetWithHttpInfo(
    String q,
    String buildingCode, {
    int? limit,
    num? latitude,
    num? longitude,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/buildings/{buildingCode}/rooms'
        .replaceAll('{buildingCode}', buildingCode);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'q', q));
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (latitude != null) {
      queryParams.addAll(_queryParams('', 'latitude', latitude));
    }
    if (longitude != null) {
      queryParams.addAll(_queryParams('', 'longitude', longitude));
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

  /// Search verified rooms in a building
  ///
  /// Searches the rooms inside one building, best match for `q` first.  Requires `Authorization: Bearer <access_token>`.  `buildingCode` is the campus building code, for example \"ECS\". It is matched case-insensitively.  ---  `q` must contain at least two meaningful characters. Whitespace inside it is ignored, so \"101\" and \"1 01\" match the same rooms.  `limit` defaults to 10 and is capped at 20.  Only active, searchable rooms are returned — never buildings, entrances, or other destination types.  A building code that does not resolve to an active, searchable building returns 404.  `latitude` and `longitude` are accepted but ignored here.
  ///
  /// Parameters:
  ///
  /// * [String] q (required):
  ///
  /// * [String] buildingCode (required):
  ///
  /// * [int] limit:
  ///
  /// * [num] latitude:
  ///
  /// * [num] longitude:
  Future<BuildingsBuildingCodeRoomsGet200Response?>
      buildingsBuildingCodeRoomsGet(
    String q,
    String buildingCode, {
    int? limit,
    num? latitude,
    num? longitude,
  }) async {
    final response = await buildingsBuildingCodeRoomsGetWithHttpInfo(
      q,
      buildingCode,
      limit: limit,
      latitude: latitude,
      longitude: longitude,
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
        'BuildingsBuildingCodeRoomsGet200Response',
      ) as BuildingsBuildingCodeRoomsGet200Response;
    }
    return null;
  }

  /// Get one campus destination
  ///
  /// Returns one active, searchable campus destination by its UUID.  Requires `Authorization: Bearer <access_token>`.  `placeId` is the `id` of a campus result from `GET /autocomplete`.  ---  A well-formed UUID with no matching active, searchable destination returns 404.  A temporary Mapbox result has a `mapbox:` prefixed `id`, which is not a UUID and returns 422.  ---  For those, use the coordinates already present on the autocomplete result.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] placeId (required):
  Future<Response> placesPlaceIdGetWithHttpInfo(
    String placeId,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/places/{placeId}'.replaceAll('{placeId}', placeId);

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

  /// Get one campus destination
  ///
  /// Returns one active, searchable campus destination by its UUID.  Requires `Authorization: Bearer <access_token>`.  `placeId` is the `id` of a campus result from `GET /autocomplete`.  ---  A well-formed UUID with no matching active, searchable destination returns 404.  A temporary Mapbox result has a `mapbox:` prefixed `id`, which is not a UUID and returns 422.  ---  For those, use the coordinates already present on the autocomplete result.
  ///
  /// Parameters:
  ///
  /// * [String] placeId (required):
  Future<PlacesPlaceIdGet200Response?> placesPlaceIdGet(
    String placeId,
  ) async {
    final response = await placesPlaceIdGetWithHttpInfo(
      placeId,
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
        'PlacesPlaceIdGet200Response',
      ) as PlacesPlaceIdGet200Response;
    }
    return null;
  }
}
