import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/registration_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const currentTestEmail = 'jane@student.csulb.edu';

/// An unsigned token shaped like a backend access token. A null [purpose]
/// leaves the `session_purpose` claim out.
String tokenWithPurpose(String? purpose) {
  String part(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final claims = <String, Object?>{'sub': 'user-1'};
  if (purpose != null) claims['session_purpose'] = purpose;
  return '${part({'alg': 'ES256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

const reauthRequiredError = RegistrationException(
  message: 'Sign in again with your password before changing your email.',
  statusCode: 401,
  code: 'REAUTH_REQUIRED',
);

class FakeEmailChangeGateway implements RegistrationGateway {
  /// One entry is consumed per `requestEmailChange` call. A null entry, or an
  /// empty list, means the call succeeds.
  final List<RegistrationException?> requestErrors = [];
  final List<({String accessToken, String newEmail})> requests = [];

  RegistrationException? signInError;
  RegistrationVerificationSuccess signInTokens =
      const RegistrationVerificationSuccess(
        accessToken: 'login-access',
        refreshToken: 'login-refresh',
      );
  final List<({String email, String password})> signIns = [];

  RegistrationException? verifyError;
  EmailChangeVerificationSuccess? verifyResult;
  final List<({String newEmail, String code})> verifications = [];

  @override
  Future<void> requestEmailChange({
    required String accessToken,
    required String newEmail,
  }) async {
    requests.add((accessToken: accessToken, newEmail: newEmail));
    if (requestErrors.isEmpty) return;
    final error = requestErrors.removeAt(0);
    if (error != null) throw error;
  }

  @override
  Future<EmailChangeVerificationSuccess> verifyEmailChangeCode({
    required String newEmail,
    required String code,
  }) async {
    verifications.add((newEmail: newEmail, code: code));
    if (verifyError != null) throw verifyError!;
    return verifyResult ??
        EmailChangeVerificationSuccess(
          tokens: RegistrationVerificationSuccess(
            accessToken: tokenWithPurpose('standard'),
            refreshToken: 'new-refresh',
          ),
          message: emailChangedFallbackMessage,
        );
  }

  @override
  Future<void> logout({required String accessToken}) async {}

  @override
  Future<RegistrationVerificationSuccess> signIn({
    required String email,
    required String password,
  }) async {
    signIns.add((email: email, password: password));
    if (signInError != null) throw signInError!;
    return signInTokens;
  }

  @override
  Future<RegistrationSuccess> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) => throw UnimplementedError();

  @override
  Future<RegistrationVerificationSuccess> verifyRegistrationCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<PasswordResetRequestSuccess> requestPasswordReset({
    required String email,
  }) => throw UnimplementedError();

  @override
  Future<RegistrationVerificationSuccess> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String accessToken,
    required String newPassword,
    required String confirmPassword,
  }) => throw UnimplementedError();
}

class FakeAuthTokenProvider implements AuthTokenProvider {
  String? current = 'stale-token';
  String? refreshed = 'fresh-token';

  /// The `forceRefresh` argument of each call, in order.
  final List<bool> calls = [];

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    calls.add(forceRefresh);
    return forceRefresh ? refreshed : current;
  }
}

/// An offline Supabase client with a restored session: a non-JWT access
/// token has no expiry, so nothing refreshes and nothing hits the network.
/// Same construction as `test/account_avatar_edit_test.dart`.
Future<SupabaseClient> signedInSupabase({required bool anonymous}) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'email': currentTestEmail,
        'created_at': '',
        'is_anonymous': anonymous,
      },
    }),
  );
  return client;
}

/// A signed-in `AppState` whose gateway, token source, session install, and
/// session discard are all fakes.
class EmailChangeHarness {
  EmailChangeHarness._();

  final gateway = FakeEmailChangeGateway();
  final tokens = FakeAuthTokenProvider();

  /// Sessions handed to `verificationSessionHandler`, in order.
  final List<RegistrationVerificationSuccess> installed = [];

  /// When set, installing a session throws this.
  Object? installError;
  int discardCount = 0;
  late final AppState state;

  static Future<EmailChangeHarness> create(
    WidgetTester tester, {
    bool anonymous = false,
  }) async {
    final harness = EmailChangeHarness._();
    final client = await signedInSupabase(anonymous: anonymous);
    harness.state = AppState(
      supabase: client,
      registrationGateway: harness.gateway,
      authTokenProvider: harness.tokens,
      verificationSessionHandler: (tokens) async {
        final error = harness.installError;
        if (error != null) throw error;
        harness.installed.add(tokens);
      },
      sessionDiscarder: () async => harness.discardCount++,
    );
    // Lets the profile and class reads started by the constructor finish
    // before the test body or teardown runs.
    await tester.pump();
    return harness;
  }
}

/// Account screens put ListTiles inside coloured Containers, which trips
/// Flutter's debug-only "ink splashes may be invisible" report. Only that
/// report is ignored; every other error still fails the test.
Future<void> ignoringInkSplashReports(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('ink splashes may be invisible')) {
      return;
    }
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}
