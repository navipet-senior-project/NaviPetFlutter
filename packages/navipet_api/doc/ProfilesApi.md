# navipet_api.api.ProfilesApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**profilesMeGet**](ProfilesApi.md#profilesmeget) | **GET** /profiles/me | Get the authenticated user profile
[**profilesMePatch**](ProfilesApi.md#profilesmepatch) | **PATCH** /profiles/me | Update the authenticated user profile


# **profilesMeGet**
> ProfilesMeGet200Response profilesMeGet()

Get the authenticated user profile

Returns the display name, email, role, and avatar of the authenticated user, as shown on the profile screen.  Requires `Authorization: Bearer <access_token>`.  `avatarUrl` is a temporary signed URL that expires after about one hour, so fetch the profile again rather than caching the URL.  `avatarUrl` is `null` when no avatar can be served; show a local placeholder instead.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ProfilesApi();

try {
    final result = api_instance.profilesMeGet();
    print(result);
} catch (e) {
    print('Exception when calling ProfilesApi->profilesMeGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ProfilesMeGet200Response**](ProfilesMeGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **profilesMePatch**
> ProfilesMeGet200Response profilesMePatch(profilesMePatchRequest)

Update the authenticated user profile

Updates the profile of the authenticated user and returns the saved profile.  Requires `Authorization: Bearer <access_token>`.  Send at least one field. Omitted fields keep their current values. Use JSON when changing text fields only. Use multipart form data when including an avatar file; send text fields as ordinary form fields and the image in a field named `avatar`.  `displayName` is trimmed and cannot be blank. To change the email, use `POST /auth/change-email`; email is deliberately not editable through this endpoint.  Avatar images must be JPEG, PNG, or WebP and no larger than 5 MB. The server stores a newly selected avatar only when this request saves successfully.  The returned `avatarUrl` is a temporary signed URL that expires after about one hour.  In Swagger UI, delete the fields you do not want to change from the example body before executing.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ProfilesApi();
final profilesMePatchRequest = ProfilesMePatchRequest(); // ProfilesMePatchRequest | 

try {
    final result = api_instance.profilesMePatch(profilesMePatchRequest);
    print(result);
} catch (e) {
    print('Exception when calling ProfilesApi->profilesMePatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profilesMePatchRequest** | [**ProfilesMePatchRequest**](ProfilesMePatchRequest.md)|  | 

### Return type

[**ProfilesMeGet200Response**](ProfilesMeGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json, multipart/form-data
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

