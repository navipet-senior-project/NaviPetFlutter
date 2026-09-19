import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A `GoTrueClient` stand-in for tests. It never talks to Supabase: instead
/// of relying on the real client's internal behavior (e.g. whether a missing
/// session is detected before or after a network round-trip — an
/// undocumented implementation detail that could change between `gotrue`
/// versions), it overrides the two members `SupabaseAuthTokenProvider`
/// touches and lets the test fully control them.
class FakeGoTrueClient extends GoTrueClient {
  FakeGoTrueClient() : super(autoRefreshToken: false);

  Session? session;
  Object? refreshError;
  int refreshCalls = 0;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    return AuthResponse(session: session);
  }
}

Session _sessionWith(String accessToken) => Session(
  accessToken: accessToken,
  tokenType: 'bearer',
  user: const User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2024-01-01T00:00:00Z',
  ),
);

void main() {
  test('returns null when no Supabase session exists', () async {
    final auth = FakeGoTrueClient();
    addTearDown(auth.dispose);
    final provider = SupabaseAuthTokenProvider(auth);

    expect(await provider.token(), isNull);
  });

  test('returns the current access token without forcing a refresh', () async {
    final auth = FakeGoTrueClient()..session = _sessionWith('token-a');
    addTearDown(auth.dispose);
    final provider = SupabaseAuthTokenProvider(auth);

    expect(await provider.token(), 'token-a');
    expect(auth.refreshCalls, 0);
  });

  test(
    'refreshes the session before returning the token when forced',
    () async {
      final auth = FakeGoTrueClient()..session = _sessionWith('token-a');
      addTearDown(auth.dispose);
      final provider = SupabaseAuthTokenProvider(auth);

      expect(await provider.token(forceRefresh: true), 'token-a');
      expect(auth.refreshCalls, 1);
    },
  );

  test('swallows a failed forced refresh instead of throwing', () async {
    final auth = FakeGoTrueClient()..refreshError = Exception('refresh failed');
    addTearDown(auth.dispose);
    final provider = SupabaseAuthTokenProvider(auth);

    expect(await provider.token(forceRefresh: true), isNull);
    expect(auth.refreshCalls, 1);
  });
}
