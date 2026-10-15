# navipet_api.model.AuthVerifyOtpPostRequest

## Load the model package
```dart
import 'package:navipet_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**email** | **String** |  | 
**code** | **String** |  | 
**type** | **String** | 'recovery' verifies a password reset code (from /auth/forgot-password); 'register' verifies an email confirmation code (from /auth/register); 'email_change' verifies the code sent to a new address (from /auth/change-email). | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


