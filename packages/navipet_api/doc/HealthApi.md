# navipet_api.api.HealthApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**healthGet**](HealthApi.md#healthget) | **GET** /health | Check API process liveness


# **healthGet**
> HealthGet200Response healthGet()

Check API process liveness

Liveness probe used as the hosting platform health check.  Public — no bearer token is needed, and it is exempt from rate limiting.  It reports only that this process is accepting requests. It does not call Supabase or MultiSet, so a 200 says nothing about their health.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = HealthApi();

try {
    final result = api_instance.healthGet();
    print(result);
} catch (e) {
    print('Exception when calling HealthApi->healthGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**HealthGet200Response**](HealthGet200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

