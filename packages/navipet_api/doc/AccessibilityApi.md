# navipet_api.api.AccessibilityApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**profilesMeAccessibilityGet**](AccessibilityApi.md#profilesmeaccessibilityget) | **GET** /profiles/me/accessibility | Get the accessibility preferences
[**profilesMeAccessibilityPatch**](AccessibilityApi.md#profilesmeaccessibilitypatch) | **PATCH** /profiles/me/accessibility | Update accessibility preferences


# **profilesMeAccessibilityGet**
> ProfilesMeAccessibilityGet200Response profilesMeAccessibilityGet()

Get the accessibility preferences

Returns the ten accessibility preferences of the authenticated user, grouped as on the Accessibility screen.  Requires `Authorization: Bearer <access_token>`. Each user sees only their own preferences.  A user who has never changed a preference gets the defaults, not a 404: voice guidance and haptic turn alerts are on, everything else is off.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AccessibilityApi();

try {
    final result = api_instance.profilesMeAccessibilityGet();
    print(result);
} catch (e) {
    print('Exception when calling AccessibilityApi->profilesMeAccessibilityGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ProfilesMeAccessibilityGet200Response**](ProfilesMeAccessibilityGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **profilesMeAccessibilityPatch**
> ProfilesMeAccessibilityGet200Response profilesMeAccessibilityPatch(profilesMeAccessibilityPatchRequest)

Update accessibility preferences

Changes one or more accessibility preferences of the authenticated user and returns all ten.  Requires `Authorization: Bearer <access_token>`. A user can change only their own preferences.  Send only the toggles that changed, inside their group. Toggles left out keep their current value.  Every toggle is independent. Turning on accessible routes does not turn on avoid stairs or prefer elevators.  The request must change at least one toggle. An empty object, an empty group, an unknown key, or a non-boolean value returns 422.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AccessibilityApi();
final profilesMeAccessibilityPatchRequest = ProfilesMeAccessibilityPatchRequest(); // ProfilesMeAccessibilityPatchRequest | 

try {
    final result = api_instance.profilesMeAccessibilityPatch(profilesMeAccessibilityPatchRequest);
    print(result);
} catch (e) {
    print('Exception when calling AccessibilityApi->profilesMeAccessibilityPatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **profilesMeAccessibilityPatchRequest** | [**ProfilesMeAccessibilityPatchRequest**](ProfilesMeAccessibilityPatchRequest.md)|  | 

### Return type

[**ProfilesMeAccessibilityGet200Response**](ProfilesMeAccessibilityGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

