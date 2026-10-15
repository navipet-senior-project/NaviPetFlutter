# navipet_api.api.ClassesApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**classesClassIdDelete**](ClassesApi.md#classesclassiddelete) | **DELETE** /classes/{classId} | Delete one authenticated user class
[**classesClassIdPatch**](ClassesApi.md#classesclassidpatch) | **PATCH** /classes/{classId} | Update one authenticated user class
[**classesGet**](ClassesApi.md#classesget) | **GET** /classes | List the authenticated user classes
[**classesPost**](ClassesApi.md#classespost) | **POST** /classes | Add a class to the authenticated user schedule


# **classesClassIdDelete**
> Object classesClassIdDelete(classId)

Delete one authenticated user class

Permanently removes one class from the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  A `classId` that is not on the authenticated user's schedule returns 404.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ClassesApi();
final classId = classId_example; // String | 

try {
    final result = api_instance.classesClassIdDelete(classId);
    print(result);
} catch (e) {
    print('Exception when calling ClassesApi->classesClassIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **classId** | **String**|  | 

### Return type

[**Object**](Object.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **classesClassIdPatch**
> ClassesClassIdPatch200Response classesClassIdPatch(classId, classesClassIdPatchRequest)

Update one authenticated user class

Changes one class on the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`.  Send only the fields being changed. An empty body returns 422.  ### Location  Omitting `building` leaves the stored location untouched.  Sending `building` resolves it again, the same way `POST /classes` does.  ---  Setting `isOnline: true` clears the stored coordinates.  Setting `isOnline: false` resolves `building` — the one sent, else the stored one. An empty building returns 422.  ### Time  `time` replaces both `startTime` and `endTime` and cannot be combined with either.  ---  Changing `weekdays`, `time`, `startTime`, `endTime`, or `courseCode` re-checks the whole class.  ---  The end time must stay later than the start time (422), and the class must not conflict with another class on the schedule (409).  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ClassesApi();
final classId = classId_example; // String | 
final classesClassIdPatchRequest = ClassesClassIdPatchRequest(); // ClassesClassIdPatchRequest | 

try {
    final result = api_instance.classesClassIdPatch(classId, classesClassIdPatchRequest);
    print(result);
} catch (e) {
    print('Exception when calling ClassesApi->classesClassIdPatch: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **classId** | **String**|  | 
 **classesClassIdPatchRequest** | [**ClassesClassIdPatchRequest**](ClassesClassIdPatchRequest.md)|  | 

### Return type

[**ClassesClassIdPatch200Response**](ClassesClassIdPatch200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **classesGet**
> ClassesGet200Response classesGet()

List the authenticated user classes

Returns every class on the authenticated user's schedule, oldest first.  Requires `Authorization: Bearer <access_token>`, using the `access_token` from `POST /auth/login`.  In Swagger UI, paste the token into the \"Authorize\" button; it is then sent with every request on this page.  A user with no classes gets an empty array.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ClassesApi();

try {
    final result = api_instance.classesGet();
    print(result);
} catch (e) {
    print('Exception when calling ClassesApi->classesGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ClassesGet200Response**](ClassesGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **classesPost**
> ClassesPost201Response classesPost(classesPostRequest)

Add a class to the authenticated user schedule

Adds one class to the authenticated user's schedule.  Requires `Authorization: Bearer <access_token>`. The example request body below works as sent.  ### Location  `building` accepts a CSULB building name or code, or a plain street address.  Either way the saved class gets a resolved display name and coordinates, used later for class-aware navigation. A building or address that cannot be found returns 404.  Set `isOnline: true` for an online class; `building` may then be omitted or empty.  An in-person class with no `building` returns 422.  ### Time  Send the time one of two ways: `time` as a CSULB range such as \"4-6:45PM\", or `startTime` with `endTime`.  ---  Sending both forms, neither form, or a time that cannot be read returns 422.  An end time that is not later than the start time returns 422.  ### Schedule conflicts  Two classes conflict when they share a weekday and their times overlap.  Back-to-back classes are allowed: one ending at 10:00 and one starting at 10:00 do not conflict.  A class with an empty `weekdays` list is asynchronous and never conflicts.  A conflicting or duplicate class is rejected with 409 and nothing is saved.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ClassesApi();
final classesPostRequest = ClassesPostRequest(); // ClassesPostRequest | 

try {
    final result = api_instance.classesPost(classesPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling ClassesApi->classesPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **classesPostRequest** | [**ClassesPostRequest**](ClassesPostRequest.md)|  | 

### Return type

[**ClassesPost201Response**](ClassesPost201Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

