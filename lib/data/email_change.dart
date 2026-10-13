import 'dart:convert';

import 'registration_gateway.dart';

enum EmailChangeStatus {
  /// The backend accepted the request. A code was sent if the address can be
  /// used; the backend does not say which.
  codeSent,

  /// The backend needs a password sign-in from the last ten minutes.
  reauthRequired,

  /// The email changed and the new session is installed.
  changed,

  /// The email changed, but the returned session cannot be used. The user is
  /// signed out and must sign in with the new email.
  changedSignInRequired,
  failure,
}

/// Which request failed. The same HTTP status means different things at
/// different steps (401 is an expired session, a wrong password, or a wrong
/// code).
enum EmailChangeStep { request, reauthenticate, verify }

class EmailChangeResult {
  const EmailChangeResult._(
    this.status, {
    this.message,
    this.errorCode,
    this.statusCode,
  });

  const EmailChangeResult.codeSent() : this._(EmailChangeStatus.codeSent);

  const EmailChangeResult.reauthRequired()
    : this._(EmailChangeStatus.reauthRequired);

  const EmailChangeResult.changed(String message)
    : this._(EmailChangeStatus.changed, message: message);

  const EmailChangeResult.changedSignInRequired(String message)
    : this._(EmailChangeStatus.changedSignInRequired, message: message);

  const EmailChangeResult.failure(
    String message, {
    String? errorCode,
    int? statusCode,
  }) : this._(
         EmailChangeStatus.failure,
         message: message,
         errorCode: errorCode,
         statusCode: statusCode,
       );

  final EmailChangeStatus status;
  final String? message;
  final String? errorCode;
  final int? statusCode;
}

const emailChangeSignInNotice =
    'Email updated. Sign in with your new email to continue.';

const emailChangePasswordRequiredMessage = 'Enter your password.';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Matches what the backend does before validating: trim, then lowercase.
String normalizeEmail(String value) => value.trim().toLowerCase();

/// Returns the text to show, or null when [candidate] may be sent.
String? validateNewEmail(String candidate, {required String currentEmail}) {
  final email = normalizeEmail(candidate);
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
  if (email == normalizeEmail(currentEmail)) {
    return 'Enter an email that is different from your current one.';
  }
  return null;
}

/// Text is chosen by step and status code. Backend 5xx code strings differ
/// between routes, so they are never matched.
String emailChangeErrorMessage(
  RegistrationException error,
  EmailChangeStep step,
) {
  final status = error.statusCode;
  if (status == 0 || status == 408) return error.message;
  if (status == 429) {
    return 'Too many attempts. Wait a few minutes and try again.';
  }
  switch (step) {
    case EmailChangeStep.request:
      // REAUTH_REQUIRED is handled before this is called. If it arrives
      // straight after a successful password sign-in, it is a plain failure.
      if (status == 401 && error.code != 'REAUTH_REQUIRED') {
        return 'Your session has expired. Sign in again to change your email.';
      }
      if (status == 422) {
        return 'Enter a valid email address that is different from your '
            'current one.';
      }
      return 'We could not send the code. Please try again.';
    case EmailChangeStep.reauthenticate:
      if (status == 401) return 'That password is incorrect.';
      if (status == 403) return error.message;
      if (status == 422) return emailChangePasswordRequiredMessage;
      return 'We could not confirm your password. Please try again.';
    case EmailChangeStep.verify:
      if (status == 401) {
        return 'That code is invalid or expired. Request a new code and try '
            'again.';
      }
      if (status == 422) return 'Enter the six-digit code from the email.';
      return 'We could not confirm the code. Please try again.';
  }
}

/// Whether the backend will accept [accessToken] on protected routes.
///
/// The backend signs a `session_purpose` claim into every access token. An
/// email-change code verified within an hour of a password-reset request
/// comes back as a `recovery` session, which only `/auth/reset-password`
/// accepts. The signature is not checked here; the backend checks it.
///
/// Fails open: a token that cannot be read is treated as standard, and a bad
/// one is then rejected by the next API call.
bool isStandardSessionToken(String accessToken) {
  final parts = accessToken.split('.');
  if (parts.length != 3) return true;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return true;
    final purpose = payload['session_purpose'];
    return purpose == null || purpose == 'standard';
  } on FormatException {
    return true;
  }
}
