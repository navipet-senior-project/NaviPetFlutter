# navipet_api.api.CampusApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**autocompleteGet**](CampusApi.md#autocompleteget) | **GET** /autocomplete | Autocomplete campus destinations
[**buildingsBuildingCodeRoomsGet**](CampusApi.md#buildingsbuildingcoderoomsget) | **GET** /buildings/{buildingCode}/rooms | Search verified rooms in a building
[**placesPlaceIdGet**](CampusApi.md#placesplaceidget) | **GET** /places/{placeId} | Get one campus destination


# **autocompleteGet**
> AutocompleteGet200Response autocompleteGet(q, limit, latitude, longitude)

Autocomplete campus destinations

Searches active, searchable CSULB campus destinations that match `q`.  Requires `Authorization: Bearer <access_token>`.  `q` must contain at least two meaningful characters, otherwise the request returns 422.  `limit` defaults to 10 and is capped at 20.  `latitude` and `longitude` are optional but must be sent together.  ---  ### Proximity search  These phrases search for the nearest matching places instead of matching by name: \"nearest restroom\", \"food near me\", \"nearest parking\", \"closest bus stop\", \"coffee near me\".  They require `latitude` and `longitude`; without them the request returns 422.  ---  Only places within 2000 meters are returned, each with `distanceMeters`, and the response gains a `proximity` object.  ---  ### Mapbox fallback  When an ordinary search finds no campus destination with outdoor coordinates, a temporary Mapbox result may be returned instead. Proximity searches never do this.  A Mapbox result has `external: true` and an `id` starting with `mapbox:`.  ---  It is not stored, so that `id` cannot be used with `GET /places/{placeId}` or `POST /recent-searches`.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = CampusApi();
final q = q_example; // String | 
final limit = 56; // int | 
final latitude = 8.14; // num | 
final longitude = 8.14; // num | 

try {
    final result = api_instance.autocompleteGet(q, limit, latitude, longitude);
    print(result);
} catch (e) {
    print('Exception when calling CampusApi->autocompleteGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **q** | **String**|  | 
 **limit** | **int**|  | [optional] 
 **latitude** | **num**|  | [optional] 
 **longitude** | **num**|  | [optional] 

### Return type

[**AutocompleteGet200Response**](AutocompleteGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **buildingsBuildingCodeRoomsGet**
> BuildingsBuildingCodeRoomsGet200Response buildingsBuildingCodeRoomsGet(q, buildingCode, limit, latitude, longitude)

Search verified rooms in a building

Searches the rooms inside one building, best match for `q` first.  Requires `Authorization: Bearer <access_token>`.  `buildingCode` is the campus building code, for example \"ECS\". It is matched case-insensitively.  ---  `q` must contain at least two meaningful characters. Whitespace inside it is ignored, so \"101\" and \"1 01\" match the same rooms.  `limit` defaults to 10 and is capped at 20.  Only active, searchable rooms are returned — never buildings, entrances, or other destination types.  A building code that does not resolve to an active, searchable building returns 404.  `latitude` and `longitude` are accepted but ignored here.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = CampusApi();
final q = q_example; // String | 
final buildingCode = buildingCode_example; // String | 
final limit = 56; // int | 
final latitude = 8.14; // num | 
final longitude = 8.14; // num | 

try {
    final result = api_instance.buildingsBuildingCodeRoomsGet(q, buildingCode, limit, latitude, longitude);
    print(result);
} catch (e) {
    print('Exception when calling CampusApi->buildingsBuildingCodeRoomsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **q** | **String**|  | 
 **buildingCode** | **String**|  | 
 **limit** | **int**|  | [optional] 
 **latitude** | **num**|  | [optional] 
 **longitude** | **num**|  | [optional] 

### Return type

[**BuildingsBuildingCodeRoomsGet200Response**](BuildingsBuildingCodeRoomsGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **placesPlaceIdGet**
> PlacesPlaceIdGet200Response placesPlaceIdGet(placeId)

Get one campus destination

Returns one active, searchable campus destination by its UUID.  Requires `Authorization: Bearer <access_token>`.  `placeId` is the `id` of a campus result from `GET /autocomplete`.  ---  A well-formed UUID with no matching active, searchable destination returns 404.  A temporary Mapbox result has a `mapbox:` prefixed `id`, which is not a UUID and returns 422.  ---  For those, use the coordinates already present on the autocomplete result.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = CampusApi();
final placeId = placeId_example; // String | 

try {
    final result = api_instance.placesPlaceIdGet(placeId);
    print(result);
} catch (e) {
    print('Exception when calling CampusApi->placesPlaceIdGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **placeId** | **String**|  | 

### Return type

[**PlacesPlaceIdGet200Response**](PlacesPlaceIdGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

