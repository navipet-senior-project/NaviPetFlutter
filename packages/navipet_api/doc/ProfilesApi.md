# navipet_api.api.ProfilesApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**profilesMeAvatarPost**](ProfilesApi.md#profilesmeavatarpost) | **POST** /profiles/me/avatar | Upload a temporary profile avatar
[**profilesMeAvatarUploadIdDelete**](ProfilesApi.md#profilesmeavataruploadiddelete) | **DELETE** /profiles/me/avatar/{uploadId} | Discard a temporary profile avatar upload
[**profilesMeGet**](ProfilesApi.md#profilesmeget) | **GET** /profiles/me | Get the authenticated user profile
[**profilesMePatch**](ProfilesApi.md#profilesmepatch) | **PATCH** /profiles/me | Update the authenticated user profile


# **profilesMeAvatarPost**
> ProfilesMeAvatarPost200Response profilesMeAvatarPost(avatar)

Upload a temporary profile avatar

Uploads one image as a temporary avatar. It is not the saved profile avatar until it is committed.  Requires `Authorization: Bearer <access_token>`.  Send `multipart/form-data` with the file in a field named `avatar`.  Accepted formats are JPEG, PNG, and WebP, up to 5 MB.  ---  **To keep it:** send the returned `uploadId` as `avatarUploadId` in `PATCH /profiles/me`.  ---  **To discard it:** call `DELETE /profiles/me/avatar/{uploadId}`.  ---  The returned `avatarUrl` is a preview link that expires after about one hour.

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
final avatar = BINARY_DATA_HERE; // MultipartFile | Avatar image file.

try {
    final result = api_instance.profilesMeAvatarPost(avatar);
    print(result);
} catch (e) {
    print('Exception when calling ProfilesApi->profilesMeAvatarPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **avatar** | **MultipartFile**| Avatar image file. | 

### Return type

[**ProfilesMeAvatarPost200Response**](ProfilesMeAvatarPost200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: multipart/form-data
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **profilesMeAvatarUploadIdDelete**
> Object profilesMeAvatarUploadIdDelete(uploadId)

Discard a temporary profile avatar upload

Discards a temporary avatar upload, for when the user cancels their profile changes.  Requires `Authorization: Bearer <access_token>`.  `uploadId` is the value returned by `POST /profiles/me/avatar`.  Do not call this after that `uploadId` has been committed through `PATCH /profiles/me`.  An upload that does not exist for this user returns 404.

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
final uploadId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final result = api_instance.profilesMeAvatarUploadIdDelete(uploadId);
    print(result);
} catch (e) {
    print('Exception when calling ProfilesApi->profilesMeAvatarUploadIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **uploadId** | **String**|  | 

### Return type

[**Object**](Object.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

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

Updates the profile of the authenticated user and returns the saved profile.  Requires `Authorization: Bearer <access_token>`.  Send at least one field. Omitted fields keep their current values.  `displayName` is trimmed and cannot be blank. To change the email, use `POST /auth/change-email`; email is deliberately not editable through this endpoint.  ---  To save a new avatar, first call `POST /profiles/me/avatar`, then send its `uploadId` here as `avatarUploadId`.  ---  The returned `avatarUrl` is a temporary signed URL that expires after about one hour.  In Swagger UI, delete the fields you do not want to change from the example body before executing.

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

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

