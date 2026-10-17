# navipet_api.api.AuthenticationApi

## Load the API package
```dart
import 'package:navipet_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authChangeEmailPost**](AuthenticationApi.md#authchangeemailpost) | **POST** /auth/change-email | Send a confirmation code to change the sign-in email
[**authForgotPasswordPost**](AuthenticationApi.md#authforgotpasswordpost) | **POST** /auth/forgot-password | Request a password reset verification code by email
[**authLoginPost**](AuthenticationApi.md#authloginpost) | **POST** /auth/login | Sign in with email and password
[**authLogoutAllPost**](AuthenticationApi.md#authlogoutallpost) | **POST** /auth/logout-all | Revoke every session for the authenticated user
[**authLogoutPost**](AuthenticationApi.md#authlogoutpost) | **POST** /auth/logout | Revoke the current session
[**authMeGet**](AuthenticationApi.md#authmeget) | **GET** /auth/me | Get the authenticated user
[**authRefreshPost**](AuthenticationApi.md#authrefreshpost) | **POST** /auth/refresh | Rotate a refresh token for a new access/refresh pair
[**authRegisterPost**](AuthenticationApi.md#authregisterpost) | **POST** /auth/register | Register with first name, last name, email, password, and role
[**authResetPasswordPost**](AuthenticationApi.md#authresetpasswordpost) | **POST** /auth/reset-password | Set a new password using a verified recovery session
[**authVerifyOtpPost**](AuthenticationApi.md#authverifyotppost) | **POST** /auth/verify-otp | Verify a one-time code for password reset, signup, or email change


# **authChangeEmailPost**
> AuthChangeEmailPost202Response authChangeEmailPost(authChangeEmailPostRequest)

Send a confirmation code to change the sign-in email

Starts an email-address change for the authenticated user.  Requires `Authorization: Bearer <access_token>` from a session that signed in with a password in the last 10 minutes.  An older session gets a 401 with code `REAUTH_REQUIRED`. Call `POST /auth/login` again and retry with the new token.  ---  The email is trimmed and lowercased. A 6-digit code is sent to the new address only.  The response is the same 202 whether or not the address already belongs to another account, so it cannot be used to look up accounts.  ---  Next step: submit the code through `POST /auth/verify-otp` with the new address as `email` and `type: \"email_change\"`.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AuthenticationApi();
final authChangeEmailPostRequest = AuthChangeEmailPostRequest(); // AuthChangeEmailPostRequest | 

try {
    final result = api_instance.authChangeEmailPost(authChangeEmailPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authChangeEmailPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authChangeEmailPostRequest** | [**AuthChangeEmailPostRequest**](AuthChangeEmailPostRequest.md)|  | 

### Return type

[**AuthChangeEmailPost202Response**](AuthChangeEmailPost202Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authForgotPasswordPost**
> AuthForgotPasswordPost200Response authForgotPasswordPost(authForgotPasswordPostRequest)

Request a password reset verification code by email

First step of password recovery: emails a 6-digit verification code to an existing account.  Public — no bearer token is needed. The email is trimmed and lowercased before the lookup.  An email with no account returns 404. This is a deliberate product choice; `POST /auth/login` hides whether an account exists.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"recovery\"`.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = AuthenticationApi();
final authForgotPasswordPostRequest = AuthForgotPasswordPostRequest(); // AuthForgotPasswordPostRequest | 

try {
    final result = api_instance.authForgotPasswordPost(authForgotPasswordPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authForgotPasswordPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authForgotPasswordPostRequest** | [**AuthForgotPasswordPostRequest**](AuthForgotPasswordPostRequest.md)|  | 

### Return type

[**AuthForgotPasswordPost200Response**](AuthForgotPasswordPost200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authLoginPost**
> AuthLoginPost200Response authLoginPost(authLoginPostRequest)

Sign in with email and password

Signs in an existing, confirmed account and returns a session.  Public — no bearer token is needed. The email is trimmed and lowercased before it is checked.  ---  Send the returned `access_token` as `Authorization: Bearer <access_token>` on every protected route.  ---  Keep `refresh_token` for `POST /auth/refresh` once the access token expires.  A newly registered account cannot sign in until its emailed code has been confirmed through `POST /auth/verify-otp`.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = AuthenticationApi();
final authLoginPostRequest = AuthLoginPostRequest(); // AuthLoginPostRequest | 

try {
    final result = api_instance.authLoginPost(authLoginPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authLoginPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authLoginPostRequest** | [**AuthLoginPostRequest**](AuthLoginPostRequest.md)|  | 

### Return type

[**AuthLoginPost200Response**](AuthLoginPost200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authLogoutAllPost**
> Object authLogoutAllPost()

Revoke every session for the authenticated user

Signs the authenticated user out everywhere.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Unlike `POST /auth/logout`, this revokes every session the user has on every device.  Afterwards no previously issued token pair works; the user must sign in again with `POST /auth/login`.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AuthenticationApi();

try {
    final result = api_instance.authLogoutAllPost();
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authLogoutAllPost: $e\n');
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

# **authLogoutPost**
> Object authLogoutPost()

Revoke the current session

Signs out the session that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Only that session is revoked — the same user stays signed in on other devices. Use `POST /auth/logout-all` to end every session.  To test: sign in, paste `access_token` into the \"Authorize\" button in Swagger UI, then execute.  A repeat call for an already-revoked session still returns 204.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AuthenticationApi();

try {
    final result = api_instance.authLogoutPost();
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authLogoutPost: $e\n');
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

# **authMeGet**
> AuthMeGet200Response authMeGet()

Get the authenticated user

Returns the account that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`.  Use it to check that a token still works and to read the account id, email, status, and creation time.  A bad or expired token returns 401. A valid token returns 403 when the account has been disabled and 404 when it has been deleted.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AuthenticationApi();

try {
    final result = api_instance.authMeGet();
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authMeGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AuthMeGet200Response**](AuthMeGet200Response.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authRefreshPost**
> AuthLoginPost200Response authRefreshPost(authRefreshPostRequest)

Rotate a refresh token for a new access/refresh pair

Exchanges a refresh token for a new access/refresh pair.  Public — no bearer token is needed. Call it once the current access token expires.  The response replaces both tokens. The submitted `refreshToken` is consumed and cannot be used again.  Reusing an already-consumed refresh token returns 401 and revokes its entire token family, so always retry with the newest token.  A recovery session from `POST /auth/verify-otp` cannot be refreshed and also returns 401.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = AuthenticationApi();
final authRefreshPostRequest = AuthRefreshPostRequest(); // AuthRefreshPostRequest | 

try {
    final result = api_instance.authRefreshPost(authRefreshPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authRefreshPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authRefreshPostRequest** | [**AuthRefreshPostRequest**](AuthRefreshPostRequest.md)|  | 

### Return type

[**AuthLoginPost200Response**](AuthLoginPost200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authRegisterPost**
> AuthRegisterPost200Response authRegisterPost(authRegisterPostRequest)

Register with first name, last name, email, password, and role

Creates an unconfirmed account and emails it a 6-digit verification code.  Public — no bearer token is needed. This call never returns access or refresh tokens.  Names and email are trimmed, and the email is lowercased, before validation.  The password needs 8 to 128 characters with at least one digit and one special character.  `role` is required and must be `student` or `professor`. It is self-declared: it is stored on the profile, can be changed later with `PATCH /profiles/me`, and is not an authorization signal.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"register\"`. That call confirms the account and signs it in.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = AuthenticationApi();
final authRegisterPostRequest = AuthRegisterPostRequest(); // AuthRegisterPostRequest | 

try {
    final result = api_instance.authRegisterPost(authRegisterPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authRegisterPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authRegisterPostRequest** | [**AuthRegisterPostRequest**](AuthRegisterPostRequest.md)|  | 

### Return type

[**AuthRegisterPost200Response**](AuthRegisterPost200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authResetPasswordPost**
> Object authResetPasswordPost(authResetPasswordPostRequest)

Set a new password using a verified recovery session

Last step of password recovery: sets a new password.  Requires a recovery `access_token` as the Bearer credential. A normal login token is rejected with 401.  ---  To test: call `POST /auth/forgot-password`, then `POST /auth/verify-otp` with `type: \"recovery\"`.  ---  Paste the `access_token` from that response into the \"Authorize\" button, then send matching `newPassword` and `confirmPassword`.  ---  The password needs 8 to 128 characters with at least one uppercase letter and one digit, and must differ from the previous one.  A successful reset signs the user out everywhere, including this recovery session. Sign in again with `POST /auth/login`.

### Example
```dart
import 'package:navipet_api/api.dart';
// TODO Configure HTTP Bearer authorization: bearerAuth
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearerAuth').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AuthenticationApi();
final authResetPasswordPostRequest = AuthResetPasswordPostRequest(); // AuthResetPasswordPostRequest | 

try {
    final result = api_instance.authResetPasswordPost(authResetPasswordPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authResetPasswordPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authResetPasswordPostRequest** | [**AuthResetPasswordPostRequest**](AuthResetPasswordPostRequest.md)|  | 

### Return type

[**Object**](Object.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authVerifyOtpPost**
> AuthVerifyOtpPost200Response authVerifyOtpPost(authVerifyOtpPostRequest)

Verify a one-time code for password reset, signup, or email change

Confirms an emailed 6-digit code and returns a session. One endpoint serves three flows, selected by `type`.  Public — no bearer token is needed. Use the \"Examples\" dropdown on the request body below to load a sample payload for any flow.  ---  ### Password reset — `type: \"recovery\"`  **Step 1.** `POST /auth/forgot-password` with `{ \"email\" }`.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"recovery\" }`.  **Step 4.** Use the returned `access_token` as the Bearer credential on `POST /auth/reset-password`.  This is a recovery session: it works only for the password reset. Other protected routes reject it with 401, and it cannot be refreshed.  ---  ### Signup email confirmation — `type: \"register\"`  **Step 1.** `POST /auth/register` with the new account details.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"register\" }`.  **Step 4.** The account is now confirmed and the returned tokens are a normal session. No separate `POST /auth/login` call is needed.  ---  ### Confirm an email change — `type: \"email_change\"`  **Step 1.** `POST /auth/change-email` with the new address and the current bearer token.  **Step 2.** Read the 6-digit code sent to the new address.  **Step 3.** Call this endpoint with the new address as `email`, the code, and `\"type\": \"email_change\"`.  **Step 4.** The sign-in email is now the new address. Replace the stored tokens with the returned session so the token carries the new email.  **Step 5.** Show the returned message to the user: the new address is the one to sign in with from now on.  ---  A wrong code and an expired code return the same 401 in every flow, so the response never reveals whether a code was ever valid.

### Example
```dart
import 'package:navipet_api/api.dart';

final api_instance = AuthenticationApi();
final authVerifyOtpPostRequest = AuthVerifyOtpPostRequest(); // AuthVerifyOtpPostRequest | 

try {
    final result = api_instance.authVerifyOtpPost(authVerifyOtpPostRequest);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authVerifyOtpPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authVerifyOtpPostRequest** | [**AuthVerifyOtpPostRequest**](AuthVerifyOtpPostRequest.md)|  | 

### Return type

[**AuthVerifyOtpPost200Response**](AuthVerifyOtpPost200Response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

