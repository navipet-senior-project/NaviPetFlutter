//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthenticationApi {
  AuthenticationApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Send a confirmation code to change the sign-in email
  ///
  /// Starts an email-address change for the authenticated user.  Requires `Authorization: Bearer <access_token>` from a session that signed in with a password in the last 10 minutes.  An older session gets a 401 with code `REAUTH_REQUIRED`. Call `POST /auth/login` again and retry with the new token.  ---  The email is trimmed and lowercased. A 6-digit code is sent to the new address only.  The response is the same 202 whether or not the address already belongs to another account, so it cannot be used to look up accounts.  ---  Next step: submit the code through `POST /auth/verify-otp` with the new address as `email` and `type: \"email_change\"`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthChangeEmailPostRequest] authChangeEmailPostRequest (required):
  Future<Response> authChangeEmailPostWithHttpInfo(
    AuthChangeEmailPostRequest authChangeEmailPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/change-email';

    // ignore: prefer_final_locals
    Object? postBody = authChangeEmailPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Send a confirmation code to change the sign-in email
  ///
  /// Starts an email-address change for the authenticated user.  Requires `Authorization: Bearer <access_token>` from a session that signed in with a password in the last 10 minutes.  An older session gets a 401 with code `REAUTH_REQUIRED`. Call `POST /auth/login` again and retry with the new token.  ---  The email is trimmed and lowercased. A 6-digit code is sent to the new address only.  The response is the same 202 whether or not the address already belongs to another account, so it cannot be used to look up accounts.  ---  Next step: submit the code through `POST /auth/verify-otp` with the new address as `email` and `type: \"email_change\"`.
  ///
  /// Parameters:
  ///
  /// * [AuthChangeEmailPostRequest] authChangeEmailPostRequest (required):
  Future<AuthChangeEmailPost202Response?> authChangeEmailPost(
    AuthChangeEmailPostRequest authChangeEmailPostRequest,
  ) async {
    final response = await authChangeEmailPostWithHttpInfo(
      authChangeEmailPostRequest,
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
        'AuthChangeEmailPost202Response',
      ) as AuthChangeEmailPost202Response;
    }
    return null;
  }

  /// Request a password reset verification code by email
  ///
  /// First step of password recovery: emails a 6-digit verification code to an existing account.  Public — no bearer token is needed. The email is trimmed and lowercased before the lookup.  An email with no account returns 404. This is a deliberate product choice; `POST /auth/login` hides whether an account exists.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"recovery\"`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthForgotPasswordPostRequest] authForgotPasswordPostRequest (required):
  Future<Response> authForgotPasswordPostWithHttpInfo(
    AuthForgotPasswordPostRequest authForgotPasswordPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/forgot-password';

    // ignore: prefer_final_locals
    Object? postBody = authForgotPasswordPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Request a password reset verification code by email
  ///
  /// First step of password recovery: emails a 6-digit verification code to an existing account.  Public — no bearer token is needed. The email is trimmed and lowercased before the lookup.  An email with no account returns 404. This is a deliberate product choice; `POST /auth/login` hides whether an account exists.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"recovery\"`.
  ///
  /// Parameters:
  ///
  /// * [AuthForgotPasswordPostRequest] authForgotPasswordPostRequest (required):
  Future<AuthForgotPasswordPost200Response?> authForgotPasswordPost(
    AuthForgotPasswordPostRequest authForgotPasswordPostRequest,
  ) async {
    final response = await authForgotPasswordPostWithHttpInfo(
      authForgotPasswordPostRequest,
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
        'AuthForgotPasswordPost200Response',
      ) as AuthForgotPasswordPost200Response;
    }
    return null;
  }

  /// Sign in with email and password
  ///
  /// Signs in an existing, confirmed account and returns a session.  Public — no bearer token is needed. The email is trimmed and lowercased before it is checked.  ---  Send the returned `access_token` as `Authorization: Bearer <access_token>` on every protected route.  ---  Keep `refresh_token` for `POST /auth/refresh` once the access token expires.  A newly registered account cannot sign in until its emailed code has been confirmed through `POST /auth/verify-otp`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthLoginPostRequest] authLoginPostRequest (required):
  Future<Response> authLoginPostWithHttpInfo(
    AuthLoginPostRequest authLoginPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/login';

    // ignore: prefer_final_locals
    Object? postBody = authLoginPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Sign in with email and password
  ///
  /// Signs in an existing, confirmed account and returns a session.  Public — no bearer token is needed. The email is trimmed and lowercased before it is checked.  ---  Send the returned `access_token` as `Authorization: Bearer <access_token>` on every protected route.  ---  Keep `refresh_token` for `POST /auth/refresh` once the access token expires.  A newly registered account cannot sign in until its emailed code has been confirmed through `POST /auth/verify-otp`.
  ///
  /// Parameters:
  ///
  /// * [AuthLoginPostRequest] authLoginPostRequest (required):
  Future<AuthLoginPost200Response?> authLoginPost(
    AuthLoginPostRequest authLoginPostRequest,
  ) async {
    final response = await authLoginPostWithHttpInfo(
      authLoginPostRequest,
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
        'AuthLoginPost200Response',
      ) as AuthLoginPost200Response;
    }
    return null;
  }

  /// Revoke every session for the authenticated user
  ///
  /// Signs the authenticated user out everywhere.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Unlike `POST /auth/logout`, this revokes every session the user has on every device.  Afterwards no previously issued token pair works; the user must sign in again with `POST /auth/login`.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> authLogoutAllPostWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/auth/logout-all';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Revoke every session for the authenticated user
  ///
  /// Signs the authenticated user out everywhere.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Unlike `POST /auth/logout`, this revokes every session the user has on every device.  Afterwards no previously issued token pair works; the user must sign in again with `POST /auth/login`.
  Future<Object?> authLogoutAllPost() async {
    final response = await authLogoutAllPostWithHttpInfo();
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
        'Object',
      ) as Object;
    }
    return null;
  }

  /// Revoke the current session
  ///
  /// Signs out the session that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Only that session is revoked — the same user stays signed in on other devices. Use `POST /auth/logout-all` to end every session.  To test: sign in, paste `access_token` into the \"Authorize\" button in Swagger UI, then execute.  A repeat call for an already-revoked session still returns 204.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> authLogoutPostWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/auth/logout';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Revoke the current session
  ///
  /// Signs out the session that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`. Takes no request body.  Only that session is revoked — the same user stays signed in on other devices. Use `POST /auth/logout-all` to end every session.  To test: sign in, paste `access_token` into the \"Authorize\" button in Swagger UI, then execute.  A repeat call for an already-revoked session still returns 204.
  Future<Object?> authLogoutPost() async {
    final response = await authLogoutPostWithHttpInfo();
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
        'Object',
      ) as Object;
    }
    return null;
  }

  /// Get the authenticated user
  ///
  /// Returns the account that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`.  Use it to check that a token still works and to read the account id, email, status, and creation time.  A bad or expired token returns 401. A valid token returns 403 when the account has been disabled and 404 when it has been deleted.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> authMeGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/auth/me';

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

  /// Get the authenticated user
  ///
  /// Returns the account that the bearer access token belongs to.  Requires `Authorization: Bearer <access_token>`.  Use it to check that a token still works and to read the account id, email, status, and creation time.  A bad or expired token returns 401. A valid token returns 403 when the account has been disabled and 404 when it has been deleted.
  Future<AuthMeGet200Response?> authMeGet() async {
    final response = await authMeGetWithHttpInfo();
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
        'AuthMeGet200Response',
      ) as AuthMeGet200Response;
    }
    return null;
  }

  /// Rotate a refresh token for a new access/refresh pair
  ///
  /// Exchanges a refresh token for a new access/refresh pair.  Public — no bearer token is needed. Call it once the current access token expires.  The response replaces both tokens. The submitted `refreshToken` is consumed and cannot be used again.  Reusing an already-consumed refresh token returns 401 and revokes its entire token family, so always retry with the newest token.  A recovery session from `POST /auth/verify-otp` cannot be refreshed and also returns 401.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthRefreshPostRequest] authRefreshPostRequest (required):
  Future<Response> authRefreshPostWithHttpInfo(
    AuthRefreshPostRequest authRefreshPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/refresh';

    // ignore: prefer_final_locals
    Object? postBody = authRefreshPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Rotate a refresh token for a new access/refresh pair
  ///
  /// Exchanges a refresh token for a new access/refresh pair.  Public — no bearer token is needed. Call it once the current access token expires.  The response replaces both tokens. The submitted `refreshToken` is consumed and cannot be used again.  Reusing an already-consumed refresh token returns 401 and revokes its entire token family, so always retry with the newest token.  A recovery session from `POST /auth/verify-otp` cannot be refreshed and also returns 401.
  ///
  /// Parameters:
  ///
  /// * [AuthRefreshPostRequest] authRefreshPostRequest (required):
  Future<AuthLoginPost200Response?> authRefreshPost(
    AuthRefreshPostRequest authRefreshPostRequest,
  ) async {
    final response = await authRefreshPostWithHttpInfo(
      authRefreshPostRequest,
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
        'AuthLoginPost200Response',
      ) as AuthLoginPost200Response;
    }
    return null;
  }

  /// Register with first name, last name, email, and password
  ///
  /// Creates an unconfirmed account and emails it a 6-digit verification code.  Public — no bearer token is needed. This call never returns access or refresh tokens.  Names and email are trimmed, and the email is lowercased, before validation.  The password needs 8 to 128 characters with at least one digit and one special character.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"register\"`. That call confirms the account and signs it in.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthRegisterPostRequest] authRegisterPostRequest (required):
  Future<Response> authRegisterPostWithHttpInfo(
    AuthRegisterPostRequest authRegisterPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/register';

    // ignore: prefer_final_locals
    Object? postBody = authRegisterPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Register with first name, last name, email, and password
  ///
  /// Creates an unconfirmed account and emails it a 6-digit verification code.  Public — no bearer token is needed. This call never returns access or refresh tokens.  Names and email are trimmed, and the email is lowercased, before validation.  The password needs 8 to 128 characters with at least one digit and one special character.  ---  Next step: submit the emailed code to `POST /auth/verify-otp` with `type: \"register\"`. That call confirms the account and signs it in.
  ///
  /// Parameters:
  ///
  /// * [AuthRegisterPostRequest] authRegisterPostRequest (required):
  Future<AuthRegisterPost200Response?> authRegisterPost(
    AuthRegisterPostRequest authRegisterPostRequest,
  ) async {
    final response = await authRegisterPostWithHttpInfo(
      authRegisterPostRequest,
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
        'AuthRegisterPost200Response',
      ) as AuthRegisterPost200Response;
    }
    return null;
  }

  /// Set a new password using a verified recovery session
  ///
  /// Last step of password recovery: sets a new password.  Requires a recovery `access_token` as the Bearer credential. A normal login token is rejected with 401.  ---  To test: call `POST /auth/forgot-password`, then `POST /auth/verify-otp` with `type: \"recovery\"`.  ---  Paste the `access_token` from that response into the \"Authorize\" button, then send matching `newPassword` and `confirmPassword`.  ---  The password needs 8 to 128 characters with at least one uppercase letter and one digit, and must differ from the previous one.  A successful reset signs the user out everywhere, including this recovery session. Sign in again with `POST /auth/login`.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthResetPasswordPostRequest] authResetPasswordPostRequest (required):
  Future<Response> authResetPasswordPostWithHttpInfo(
    AuthResetPasswordPostRequest authResetPasswordPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/reset-password';

    // ignore: prefer_final_locals
    Object? postBody = authResetPasswordPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Set a new password using a verified recovery session
  ///
  /// Last step of password recovery: sets a new password.  Requires a recovery `access_token` as the Bearer credential. A normal login token is rejected with 401.  ---  To test: call `POST /auth/forgot-password`, then `POST /auth/verify-otp` with `type: \"recovery\"`.  ---  Paste the `access_token` from that response into the \"Authorize\" button, then send matching `newPassword` and `confirmPassword`.  ---  The password needs 8 to 128 characters with at least one uppercase letter and one digit, and must differ from the previous one.  A successful reset signs the user out everywhere, including this recovery session. Sign in again with `POST /auth/login`.
  ///
  /// Parameters:
  ///
  /// * [AuthResetPasswordPostRequest] authResetPasswordPostRequest (required):
  Future<Object?> authResetPasswordPost(
    AuthResetPasswordPostRequest authResetPasswordPostRequest,
  ) async {
    final response = await authResetPasswordPostWithHttpInfo(
      authResetPasswordPostRequest,
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
        'Object',
      ) as Object;
    }
    return null;
  }

  /// Verify a one-time code for password reset, signup, or email change
  ///
  /// Confirms an emailed 6-digit code and returns a session. One endpoint serves three flows, selected by `type`.  Public — no bearer token is needed. Use the \"Examples\" dropdown on the request body below to load a sample payload for any flow.  ---  ### Password reset — `type: \"recovery\"`  **Step 1.** `POST /auth/forgot-password` with `{ \"email\" }`.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"recovery\" }`.  **Step 4.** Use the returned `access_token` as the Bearer credential on `POST /auth/reset-password`.  This is a recovery session: it works only for the password reset. Other protected routes reject it with 401, and it cannot be refreshed.  ---  ### Signup email confirmation — `type: \"register\"`  **Step 1.** `POST /auth/register` with the new account details.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"register\" }`.  **Step 4.** The account is now confirmed and the returned tokens are a normal session. No separate `POST /auth/login` call is needed.  ---  ### Confirm an email change — `type: \"email_change\"`  **Step 1.** `POST /auth/change-email` with the new address and the current bearer token.  **Step 2.** Read the 6-digit code sent to the new address.  **Step 3.** Call this endpoint with the new address as `email`, the code, and `\"type\": \"email_change\"`.  **Step 4.** The sign-in email is now the new address. Replace the stored tokens with the returned session so the token carries the new email.  **Step 5.** Show the returned message to the user: the new address is the one to sign in with from now on.  ---  A wrong code and an expired code return the same 401 in every flow, so the response never reveals whether a code was ever valid.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AuthVerifyOtpPostRequest] authVerifyOtpPostRequest (required):
  Future<Response> authVerifyOtpPostWithHttpInfo(
    AuthVerifyOtpPostRequest authVerifyOtpPostRequest,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/auth/verify-otp';

    // ignore: prefer_final_locals
    Object? postBody = authVerifyOtpPostRequest;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Verify a one-time code for password reset, signup, or email change
  ///
  /// Confirms an emailed 6-digit code and returns a session. One endpoint serves three flows, selected by `type`.  Public — no bearer token is needed. Use the \"Examples\" dropdown on the request body below to load a sample payload for any flow.  ---  ### Password reset — `type: \"recovery\"`  **Step 1.** `POST /auth/forgot-password` with `{ \"email\" }`.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"recovery\" }`.  **Step 4.** Use the returned `access_token` as the Bearer credential on `POST /auth/reset-password`.  This is a recovery session: it works only for the password reset. Other protected routes reject it with 401, and it cannot be refreshed.  ---  ### Signup email confirmation — `type: \"register\"`  **Step 1.** `POST /auth/register` with the new account details.  **Step 2.** Read the 6-digit code from that inbox.  **Step 3.** `POST /auth/verify-otp` with `{ \"email\", \"code\", \"type\": \"register\" }`.  **Step 4.** The account is now confirmed and the returned tokens are a normal session. No separate `POST /auth/login` call is needed.  ---  ### Confirm an email change — `type: \"email_change\"`  **Step 1.** `POST /auth/change-email` with the new address and the current bearer token.  **Step 2.** Read the 6-digit code sent to the new address.  **Step 3.** Call this endpoint with the new address as `email`, the code, and `\"type\": \"email_change\"`.  **Step 4.** The sign-in email is now the new address. Replace the stored tokens with the returned session so the token carries the new email.  **Step 5.** Show the returned message to the user: the new address is the one to sign in with from now on.  ---  A wrong code and an expired code return the same 401 in every flow, so the response never reveals whether a code was ever valid.
  ///
  /// Parameters:
  ///
  /// * [AuthVerifyOtpPostRequest] authVerifyOtpPostRequest (required):
  Future<AuthVerifyOtpPost200Response?> authVerifyOtpPost(
    AuthVerifyOtpPostRequest authVerifyOtpPostRequest,
  ) async {
    final response = await authVerifyOtpPostWithHttpInfo(
      authVerifyOtpPostRequest,
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
        'AuthVerifyOtpPost200Response',
      ) as AuthVerifyOtpPost200Response;
    }
    return null;
  }
}
