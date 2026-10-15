# navipet_api.api.RecentSearchesApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**allRecentSearchesDelete**](RecentSearchesApi.md#allrecentsearchesdelete) | **DELETE** /all-recent-searches | Clear all recent selected campus places
[**recentSearchesDelete**](RecentSearchesApi.md#recentsearchesdelete) | **DELETE** /recent-searches | Clear all recent selected campus places
[**recentSearchesGet**](RecentSearchesApi.md#recentsearchesget) | **GET** /recent-searches | Get recent selected campus places
[**recentSearchesPost**](RecentSearchesApi.md#recentsearchespost) | **POST** /recent-searches | Save a selected campus place


# **allRecentSearchesDelete**
> Object allRecentSearchesDelete()

Clear all recent selected campus places

Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RecentSearchesApi();

try {
    final result = api_instance.allRecentSearchesDelete();
    print(result);
} catch (e) {
    print('Exception when calling RecentSearchesApi->allRecentSearchesDelete: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**Object**](Object.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recentSearchesDelete**
> Object recentSearchesDelete()

Clear all recent selected campus places

Deletes every recent search that belongs to the authenticated user.  Requires `Authorization: Bearer <access_token>`. Takes no request body, and never touches another user's history.  There is no per-entry delete.  Clearing an already-empty history also returns 204.  `DELETE /recent-searches` and `DELETE /all-recent-searches` behave identically.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RecentSearchesApi();

try {
    final result = api_instance.recentSearchesDelete();
    print(result);
} catch (e) {
    print('Exception when calling RecentSearchesApi->recentSearchesDelete: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**Object**](Object.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recentSearchesGet**
> RecentSearchesGet200Response recentSearchesGet(limit)

Get recent selected campus places

Returns the authenticated user's saved places, most recently searched first.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own list.  Each entry carries the place fields plus a `searchedAt` timestamp.  `limit` defaults to 10 and is capped at 20.  A user with no history gets an empty array, not a 404.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RecentSearchesApi();
final limit = 56; // int | 

try {
    final result = api_instance.recentSearchesGet(limit);
    print(result);
} catch (e) {
    print('Exception when calling RecentSearchesApi->recentSearchesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] 

### Return type

[**RecentSearchesGet200Response**](RecentSearchesGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recentSearchesPost**
> RecentSearchesPost201Response recentSearchesPost(recentSearchesPostRequest)

Save a selected campus place

Records that the authenticated user picked a campus place, so it appears in `GET /recent-searches`.  Requires `Authorization: Bearer <access_token>`. Each user can read and write only their own list.  ---  Send the `id` of a campus result from `GET /autocomplete` as `placeId`.  The place is looked up again on the server; the stored copy comes from the database, not from the request.  Saving a place that is already in the list refreshes its timestamp instead of adding a duplicate, so the call is safe to repeat.  A well-formed UUID with no matching place returns 404.  A temporary Mapbox result (`mapbox:` prefixed `id`) cannot be saved and returns 422.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RecentSearchesApi();
final recentSearchesPostRequest = RecentSearchesPostRequest(); // RecentSearchesPostRequest | 

try {
    final result = api_instance.recentSearchesPost(recentSearchesPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling RecentSearchesApi->recentSearchesPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **recentSearchesPostRequest** | [**RecentSearchesPostRequest**](RecentSearchesPostRequest.md)|  | 

### Return type

[**RecentSearchesPost201Response**](RecentSearchesPost201Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

