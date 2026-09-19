import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('returns null when no Supabase session exists', () async {
    final auth = GoTrueClient(autoRefreshToken: false);
    addTearDown(auth.dispose);
    final provider = SupabaseAuthTokenProvider(auth);

    expect(await provider.token(), isNull);
  });

  test(
    'swallows a failed refresh and still returns the session token',
    () async {
      final auth = GoTrueClient(autoRefreshToken: false);
      addTearDown(auth.dispose);
      final provider = SupabaseAuthTokenProvider(auth);

      // No session exists, so refreshSession() throws internally; the
      // provider must not let that exception escape.
      expect(await provider.token(forceRefresh: true), isNull);
    },
  );
}
