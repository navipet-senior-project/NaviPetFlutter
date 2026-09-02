import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'course_class.dart';
import 'registration_gateway.dart';
import 'user_account.dart';

/// App-wide authentication and profile state backed by Supabase.
class AppState extends ChangeNotifier {
  AppState({SupabaseClient? supabase, RegistrationGateway? registrationGateway})
    : this._(supabase, registrationGateway);

  AppState._(this._supabase, this._registrationGateway) {
    if (_supabase == null) return;

    _applyUser(_supabase.auth.currentUser);
    _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      _isPasswordRecovery = event.event == AuthChangeEvent.passwordRecovery;
      _applyUser(event.session?.user);
    });
  }

  final SupabaseClient? _supabase;
  final RegistrationGateway? _registrationGateway;
  StreamSubscription<AuthState>? _authSubscription;

  UserAccount? _activeUser;
  bool _busy = false;
  bool _isPasswordRecovery = false;
  AuthTokens? _passwordRecoveryTokens;
  String? _errorMessage;
  List<CourseClass> _classes = const [];
  Set<String> _completionKeys = const {};
  Map<String, int> _completionCounts = const {};
  bool _classesBusy = false;

  bool get isSupabaseConfigured => _supabase != null;
  bool get isAuthenticated => _supabase?.auth.currentSession != null;
  bool get isBusy => _busy;
  bool get isPasswordRecovery => _isPasswordRecovery;

  /// True while the backend recovery session from `/auth/verify-otp` is held.
  ///
  /// This session deliberately lives outside the Supabase SDK, so it is not
  /// reflected by [isAuthenticated] and the router has to gate `/new-password`
  /// on this flag instead.
  bool get hasPasswordRecoverySession => _passwordRecoveryTokens != null;

  String? get errorMessage => _errorMessage;
  UserAccount? get activeUser => _activeUser;
  List<CourseClass> get classes => List.unmodifiable(_classes);
  bool get classesBusy => _classesBusy;

  List<DailyClassTask> dailyTasks([DateTime? day]) {
    final date = day ?? DateTime.now();
    final scheduled = _classes.where((course) => course.occursOn(date.weekday));
    final source = scheduled.isEmpty ? _classes.take(3) : scheduled;
    return source.map((course) {
      final kind = scheduled.isEmpty ? 'prepare' : 'attend';
      return DailyClassTask(
        course: course,
        kind: kind,
        label: kind == 'attend'
            ? 'Go to ${course.locationLabel} for ${course.courseCode}'
            : 'Prepare for ${course.courseCode}',
        reward: kind == 'attend' ? 10 : 5,
        done: _completionKeys.contains(
          dailyCompletionKey(course.id, date, kind),
        ),
      );
    }).toList();
  }

  int completionCountFor(String classId) => _completionCounts[classId] ?? 0;

  Future<void> refreshClasses() async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    _classesBusy = true;
    notifyListeners();
    try {
      final classRows = await client
          .from('classes')
          .select()
          .eq('user_id', user.id)
          .order('start_time');
      final completionRows = await client
          .from('task_completions')
          .select('class_id, task_date, task_kind')
          .eq('user_id', user.id);
      _classes = (classRows as List<dynamic>)
          .map((row) => CourseClass.fromJson(row as Map<String, dynamic>))
          .toList();
      final keys = <String>{};
      final counts = <String, int>{};
      for (final value in completionRows as List<dynamic>) {
        final row = value as Map<String, dynamic>;
        final classId = row['class_id'].toString();
        keys.add('$classId|${row['task_date']}|${row['task_kind']}');
        counts[classId] = (counts[classId] ?? 0) + 1;
      }
      _completionKeys = keys;
      _completionCounts = counts;
    } on PostgrestException catch (error) {
      _errorMessage = error.message;
    } finally {
      _classesBusy = false;
      notifyListeners();
    }
  }

  Future<void> saveClass(CourseClassInput input) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before adding a class.');
    _classesBusy = true;
    notifyListeners();
    try {
      final values = input.toJson(user.id);
      if (input.id == null) {
        await client.from('classes').insert(values);
      } else {
        await client.from('classes').update(values).eq('id', input.id!);
      }
      await refreshClasses();
    } finally {
      _classesBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteClass(String id) async {
    await _requireClient().from('classes').delete().eq('id', id);
    await refreshClasses();
  }

  Future<void> toggleTask(DailyClassTask task, DateTime date) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) return;
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (task.done) {
      await client
          .from('task_completions')
          .delete()
          .eq('user_id', user.id)
          .eq('class_id', task.course.id)
          .eq('task_date', dateText)
          .eq('task_kind', task.kind);
    } else {
      await client.from('task_completions').insert({
        'user_id': user.id,
        'class_id': task.course.id,
        'task_date': dateText,
        'task_kind': task.kind,
      });
    }
    await refreshClasses();
  }

  Future<AuthActionResult> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      final client = _requireClient();
      final gateway = _registrationGateway;
      if (gateway is BackendAuthGateway) {
        final tokens = await gateway.login(
          email: email.trim(),
          password: password,
        );
        final response = await client.auth.setSession(tokens.refreshToken);
        if (response.user == null) {
          return const AuthActionResult.failure(
            'Sign in did not return a user.',
          );
        }
        return const AuthActionResult.authenticated();
      }
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        return const AuthActionResult.failure('Sign in did not return a user.');
      }
      return const AuthActionResult.authenticated();
    });
  }

  Future<AuthActionResult> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      final gateway = _registrationGateway;
      if (gateway != null) {
        final result = await gateway.register(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
        );
        return AuthActionResult.emailConfirmationRequired(result.message);
      }

      final response = await _requireClient().auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'navipet://auth-callback',
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'display_name': '${firstName.trim()} ${lastName.trim()}'.trim(),
        },
      );
      return response.session == null
          ? const AuthActionResult.emailConfirmationRequired(
              'Confirmation email sent. Check your inbox.',
            )
          : const AuthActionResult.authenticated();
    });
  }

  Future<AuthActionResult> continueAsGuest() async {
    return _runAuthAction(() async {
      final response = await _requireClient().auth.signInAnonymously(
        data: {'display_name': 'Guest Explorer'},
      );
      if (response.user == null) {
        return const AuthActionResult.failure(
          'Guest sign in did not return a user.',
        );
      }
      return const AuthActionResult.authenticated();
    });
  }

  Future<AuthActionResult> sendPasswordReset(String email) async {
    return _runAuthAction(() async {
      final gateway = _registrationGateway;
      if (gateway is BackendAuthGateway) {
        await gateway.requestPasswordReset(email.trim());
        return const AuthActionResult.passwordResetSent();
      }
      await _requireClient().auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'navipet://auth-callback',
      );
      return const AuthActionResult.passwordResetSent();
    });
  }

  Future<AuthActionResult> verifyEmailCode({
    required String email,
    required String code,
    required bool isPasswordRecovery,
  }) async {
    return _runAuthAction(() async {
      final gateway = _registrationGateway;
      if (gateway is BackendAuthGateway) {
        final tokens = await gateway.verifyOtp(
          email: email.trim(),
          code: code.trim(),
          isPasswordRecovery: isPasswordRecovery,
        );
        if (isPasswordRecovery) {
          // The recovery session belongs to `/auth/reset-password` and nothing
          // else. Handing its refresh token to the Supabase SDK rotates the
          // token, which retires the session the recovery *access* token names,
          // and step 3 then fails with:
          //   Session from session_id claim in JWT does not exist
          // So hold the tokens here and make no Supabase call until the reset
          // has completed.
          _passwordRecoveryTokens = tokens;
          return const AuthActionResult.passwordRecoveryReady();
        }
        final response = await _requireClient().auth.setSession(
          tokens.refreshToken,
        );
        _isPasswordRecovery = false;
        if (response.user == null) {
          return const AuthActionResult.failure(
            'Verification did not return a user.',
          );
        }
        return const AuthActionResult.authenticated();
      }
      final response = await _requireClient().auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: isPasswordRecovery ? OtpType.recovery : OtpType.signup,
      );
      _isPasswordRecovery = isPasswordRecovery;
      if (response.user == null) {
        return const AuthActionResult.failure(
          'Verification did not return a user.',
        );
      }
      return const AuthActionResult.authenticated();
    });
  }

  Future<AuthActionResult> resendVerificationCode({
    required String email,
    required bool isPasswordRecovery,
  }) async {
    if (isPasswordRecovery) return sendPasswordReset(email);
    return _runAuthAction(() async {
      await _requireClient().auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return const AuthActionResult.emailConfirmationRequired();
    });
  }

  Future<AuthActionResult> updatePassword(String password) async {
    return _runAuthAction(() async {
      final gateway = _registrationGateway;
      if (gateway is BackendAuthGateway) {
        final recovery = _passwordRecoveryTokens;
        if (recovery == null) {
          return const AuthActionResult.failure(
            'Your password reset session has expired. Request a new code.',
            code: 'INVALID_ACCESS_TOKEN',
          );
        }
        try {
          await gateway.resetPassword(
            accessToken: recovery.accessToken,
            newPassword: password,
          );
        } on RegistrationException catch (error) {
          // A rejected token cannot be retried on the same screen — the flow
          // has to restart at `/auth/forgot-password`. Every other code
          // (422 / 429 / 500) keeps the session so the user can correct the
          // password in place.
          if (error.code == 'INVALID_ACCESS_TOKEN') _clearPasswordRecovery();
          rethrow;
        }
        // A 204 leaves the recovery session alive, but this app sends the user
        // to the sign-in screen with the new password, so the tokens are simply
        // dropped. No Supabase call belongs here: the reset flow never gave the
        // SDK a session to sign out of.
        _clearPasswordRecovery();
        return const AuthActionResult.passwordUpdated();
      }

      await _requireClient().auth.updateUser(UserAttributes(password: password));
      _clearPasswordRecovery();
      await _requireClient().auth.signOut();
      return const AuthActionResult.passwordUpdated();
    });
  }

  /// Abandons an in-progress reset. The backend session simply expires on its
  /// own after an hour; nothing needs to be revoked here.
  void discardPasswordRecovery() => _clearPasswordRecovery();

  void _clearPasswordRecovery() {
    _passwordRecoveryTokens = null;
    _isPasswordRecovery = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _requireClient().auth.signOut();
      _isPasswordRecovery = false;
      _passwordRecoveryTokens = null;
      _activeUser = null;
      _errorMessage = null;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<AuthActionResult> _runAuthAction(
    Future<AuthActionResult> Function() action,
  ) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      return await action();
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return AuthActionResult.failure(error.message);
    } on PostgrestException catch (error) {
      _errorMessage = error.message;
      return AuthActionResult.failure(error.message);
    } on RegistrationException catch (error) {
      _errorMessage = error.message;
      return AuthActionResult.failure(error.message, code: error.code);
    } on TimeoutException {
      const message =
          'The request timed out. Check your connection and try again.';
      _errorMessage = message;
      return const AuthActionResult.failure(message);
    } on StateError catch (error) {
      final message = error.message.toString();
      _errorMessage = message;
      return AuthActionResult.failure(message);
    } catch (error) {
      _errorMessage = error.toString();
      return AuthActionResult.failure(
        isSupabaseConfigured
            ? 'Something went wrong. Please try again.'
            : 'Supabase is not configured yet. Add its URL and publishable key to .env.',
      );
    } finally {
      _setBusy(false);
    }
  }

  SupabaseClient _requireClient() {
    final client = _supabase;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Add SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY to .env.',
      );
    }
    return client;
  }

  void _applyUser(User? user) {
    if (user == null) {
      _activeUser = null;
      _classes = const [];
      _completionKeys = const {};
      _completionCounts = const {};
      notifyListeners();
      return;
    }

    // Authentication should never wait for optional profile or class queries.
    // User metadata gives the UI an immediate account while those records load.
    _activeUser = UserAccount.fromSupabase(user);
    notifyListeners();
    unawaited(_hydrateUserProfile(user));
    unawaited(refreshClasses());
  }

  Future<void> _hydrateUserProfile(User user) async {
    Map<String, dynamic>? profile;
    try {
      profile = await _supabase
          ?.from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // Authentication still works before the optional profiles schema has
      // been installed. User metadata supplies a useful fallback.
    }

    if (_supabase?.auth.currentUser?.id != user.id) return;
    _activeUser = UserAccount.fromSupabase(user, profile: profile);
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

enum AuthActionStatus {
  authenticated,
  emailConfirmationRequired,
  passwordResetSent,

  /// A recovery code was verified and the reset session is held in memory.
  /// The user is *not* signed in — only `/auth/reset-password` may be called.
  passwordRecoveryReady,
  passwordUpdated,
  failure,
}

class AuthActionResult {
  const AuthActionResult._(this.status, [this.message, this.code]);

  const AuthActionResult.authenticated()
    : this._(AuthActionStatus.authenticated);

  const AuthActionResult.emailConfirmationRequired([String? message])
    : this._(AuthActionStatus.emailConfirmationRequired, message);

  const AuthActionResult.passwordResetSent()
    : this._(AuthActionStatus.passwordResetSent);

  const AuthActionResult.passwordRecoveryReady()
    : this._(AuthActionStatus.passwordRecoveryReady);

  const AuthActionResult.passwordUpdated()
    : this._(AuthActionStatus.passwordUpdated);

  const AuthActionResult.failure(String message, {String? code})
    : this._(AuthActionStatus.failure, message, code);

  final AuthActionStatus status;
  final String? message;

  /// The backend's `error.code`, when the failure came from the NaviPet API.
  /// Branch on this rather than on [message].
  final String? code;
}
