import 'package:supabase_flutter/supabase_flutter.dart';

/// Supplies the Supabase access token that the campus API requires.
abstract interface class AuthTokenProvider {
  /// Returns the current access token, or `null` when no session exists.
  ///
  /// [forceRefresh] asks the backing session to rotate before returning, which
  /// the gateways use exactly once after a 401.
  Future<String?> token({bool forceRefresh = false});
}

class SupabaseAuthTokenProvider implements AuthTokenProvider {
  SupabaseAuthTokenProvider(this._auth);

  final GoTrueClient _auth;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    if (forceRefresh) {
      try {
        await _auth.refreshSession();
      } on Object {
        // A failed refresh leaves the stale token in place; the caller turns
        // the resulting second 401 into a sign-in prompt.
      }
    }
    return _auth.currentSession?.accessToken;
  }
}
