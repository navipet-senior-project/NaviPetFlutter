import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'course_class.dart';
import 'classes_gateway.dart';
import 'registration_gateway.dart';
import 'user_account.dart';

/// App-wide authentication and profile state backed by Supabase.
class AppState extends ChangeNotifier {
  AppState({
    SupabaseClient? supabase,
    RegistrationGateway? registrationGateway,
    Future<void> Function(RegistrationVerificationSuccess tokens)?
    verificationSessionHandler,
    Future<void> Function(String email)? signupCodeResender,
    Future<RegistrationVerificationSuccess> Function(
      RegistrationVerificationSuccess tokens,
    )?
    recoverySessionRefresher,
    Future<void> Function(String newPassword)? recoveryPasswordFallback,
    ClassesGateway? classesGateway,
  }) : this._(
         supabase,
         registrationGateway,
         verificationSessionHandler,
         signupCodeResender,
         recoverySessionRefresher,
         recoveryPasswordFallback,
         classesGateway,
       );

  AppState._(
    this._supabase,
    this._registrationGateway,
    this._verificationSessionHandler,
    this._signupCodeResender,
    this._recoverySessionRefresher,
    this._recoveryPasswordFallback,
    this._classesGateway,
  ) {
    if (_supabase == null) return;

    _applyUser(_supabase.auth.currentUser);
    _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      _applyUser(event.session?.user);
    });
  }

  final SupabaseClient? _supabase;
  final RegistrationGateway? _registrationGateway;
  // Kept for when the backend exposes /classes; see refreshClasses().
  // ignore: unused_field
  final ClassesGateway? _classesGateway;
  final Future<void> Function(RegistrationVerificationSuccess tokens)?
  _verificationSessionHandler;
  final Future<void> Function(String email)? _signupCodeResender;
  final Future<RegistrationVerificationSuccess> Function(
    RegistrationVerificationSuccess tokens,
  )?
  _recoverySessionRefresher;
  final Future<void> Function(String newPassword)? _recoveryPasswordFallback;
  StreamSubscription<AuthState>? _authSubscription;
  RegistrationVerificationSuccess? _pendingRecoverySession;
  bool _passwordRecoveryInProgress = false;

  UserAccount? _activeUser;
  bool _busy = false;
  String? _errorMessage;
  List<CourseClass> _classes = const [];
  Set<String> _completionKeys = const {};
  Map<String, int> _completionCounts = const {};
  bool _classesBusy = false;

  bool get isSupabaseConfigured => _supabase != null;
  bool get isAuthenticationConfigured =>
      _registrationGateway != null &&
      (_supabase != null || _verificationSessionHandler != null);
  bool get isAuthenticated =>
      !_passwordRecoveryInProgress && _supabase?.auth.currentSession != null;
  bool get isBusy => _busy;
  bool get isPasswordRecovery => _passwordRecoveryInProgress;
  bool get hasPasswordRecoverySession => _pendingRecoverySession != null;

  String? get errorMessage => _errorMessage;
  UserAccount? get activeUser => _activeUser;
  List<CourseClass> get classes => List.unmodifiable(_classes);
  bool get classesBusy => _classesBusy;
  bool get hasPendingPasswordRecovery => _pendingRecoverySession != null;

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
      // Classes are persisted in Supabase. The currently deployed NaviPet
      // backend does not expose a /classes route, so using the optional HTTP
      // gateway here makes class loading fail with 404 before Supabase can be
      // queried.
      final classRows = await client
          .from('classes')
          .select()
          .eq('user_id', user.id)
          .order('start_time');
      _classes = (classRows as List<dynamic>)
          .map((row) => CourseClass.fromJson(row as Map<String, dynamic>))
          .toList();
      final completionRows = await client
          .from('task_completions')
          .select('class_id, task_date, task_kind')
          .eq('user_id', user.id);
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
    final client = _requireClient();
    await client.from('classes').delete().eq('id', id);
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
      final tokens = await _requireRegistrationGateway().signIn(
        email: email.trim(),
        password: password,
      );
      await _establishSession(tokens);
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
      final gateway = _requireRegistrationGateway();
      late final RegistrationSuccess result;
      try {
        result = await gateway.register(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
        );
      } on RegistrationException catch (error) {
        if (_isExistingAccountError(error)) {
          throw const RegistrationException(
            message:
                'An account with this email already exists. Please log in or use a different email.',
            statusCode: 409,
            code: 'EMAIL_ALREADY_EXISTS',
          );
        }
        rethrow;
      }
      if (!result.otpRequired) {
        throw const RegistrationException(
          message: 'The backend did not request an email verification code.',
          statusCode: 502,
          code: 'OTP_NOT_REQUIRED',
        );
      }
      return AuthActionResult.emailVerificationRequired(result.message);
    });
  }

  Future<AuthActionResult> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    return _runAuthAction(() async {
      final gateway = _requireRegistrationGateway();
      final tokens = await gateway.verifyRegistrationCode(
        email: email.trim(),
        code: code.trim(),
      );
      await _establishSession(tokens);
      return const AuthActionResult.authenticated();
    });
  }

  Future<AuthActionResult> resendRegistrationCode(String email) async {
    return _runAuthAction(() async {
      final normalizedEmail = email.trim();
      final resender = _signupCodeResender;
      if (resender != null) {
        await resender(normalizedEmail);
      } else {
        await _requireClient().auth.resend(
          type: OtpType.signup,
          email: normalizedEmail,
        );
      }
      return const AuthActionResult.codeResent(
        'A new verification code was sent.',
      );
    });
  }

  Future<AuthActionResult> requestPasswordReset(String email) async {
    return _runAuthAction(() async {
      final result = await _requireRegistrationGateway().requestPasswordReset(
        email: email.trim(),
      );
      return AuthActionResult.passwordResetCodeSent(result.message);
    });
  }

  Future<AuthActionResult> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) async {
    return _runAuthAction(() async {
      _pendingRecoverySession = await _requireRegistrationGateway()
          .verifyPasswordRecoveryCode(email: email.trim(), code: code.trim());
      return const AuthActionResult.passwordRecoveryVerified();
    });
  }

  Future<AuthActionResult> resendPasswordRecoveryCode(String email) =>
      _runAuthAction(() async {
        await _requireRegistrationGateway().requestPasswordReset(
          email: email.trim(),
        );
        return const AuthActionResult.codeResent(
          'A new verification code was sent.',
        );
      });

  Future<AuthActionResult> resetPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _runAuthAction(() async {
      var tokens = _pendingRecoverySession;
      if (tokens == null) {
        throw const RegistrationException(
          message: 'Verify your recovery code before resetting the password.',
          statusCode: 401,
          code: 'RECOVERY_SESSION_MISSING',
        );
      }
      final shouldRefresh =
          _recoverySessionRefresher != null ||
          _verificationSessionHandler == null;
      if (shouldRefresh) {
        _passwordRecoveryInProgress = true;
        notifyListeners();
        tokens = await _refreshRecoverySession(tokens);
        _pendingRecoverySession = tokens;
      }

      try {
        await _requireRegistrationGateway().resetPassword(
          accessToken: tokens.accessToken,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
      } on RegistrationException catch (error) {
        if (!_isMissingJwtSession(error)) rethrow;
        await _updateRecoveryPasswordDirectly(newPassword);
      }

      if (!shouldRefresh) await _establishSession(tokens);
      _pendingRecoverySession = null;
      _passwordRecoveryInProgress = false;
      notifyListeners();
      return const AuthActionResult.authenticated();
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

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _requireClient().auth.signOut();
      _activeUser = null;
      _pendingRecoverySession = null;
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
      return AuthActionResult.failure(
        error.message,
        errorCode: error.code,
        statusCode: error.statusCode,
      );
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

  RegistrationGateway _requireRegistrationGateway() {
    final gateway = _registrationGateway;
    if (gateway == null) {
      throw StateError(
        'The NaviPet backend is not configured. Add BACKEND_BASE_URL to .env.',
      );
    }
    return gateway;
  }

  Future<void> _establishSession(RegistrationVerificationSuccess tokens) async {
    final sessionHandler = _verificationSessionHandler;
    if (sessionHandler != null) {
      await sessionHandler(tokens);
      _pendingRecoverySession = null;
      _passwordRecoveryInProgress = false;
      notifyListeners();
      return;
    }
    final response = await _requireClient().auth.setSession(
      tokens.refreshToken,
      accessToken: tokens.accessToken,
    );
    await _applyUser(response.user);
    _pendingRecoverySession = null;
    _passwordRecoveryInProgress = false;
    notifyListeners();
  }

  bool _isExistingAccountError(RegistrationException error) {
    final code = error.code?.toLowerCase().replaceAll('-', '_') ?? '';
    final message = error.message.toLowerCase();
    return error.statusCode == 409 ||
        code.contains('already_exists') ||
        code.contains('email_exists') ||
        code.contains('user_exists') ||
        message.contains('already registered') ||
        message.contains('already exists');
  }

  Future<RegistrationVerificationSuccess> _refreshRecoverySession(
    RegistrationVerificationSuccess tokens,
  ) async {
    final refresher = _recoverySessionRefresher;
    if (refresher != null) return refresher(tokens);

    final response = await _requireClient().auth.refreshSession(
      tokens.refreshToken,
    );
    final session = response.session;
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) {
      throw const RegistrationException(
        message: 'The recovery session expired. Request a new code.',
        statusCode: 401,
        code: 'RECOVERY_SESSION_EXPIRED',
      );
    }
    return RegistrationVerificationSuccess(
      accessToken: session.accessToken,
      refreshToken: refreshToken,
    );
  }

  bool _isMissingJwtSession(RegistrationException error) {
    final message = error.message.toLowerCase();
    return message.contains('session_id') && message.contains('does not exist');
  }

  Future<void> _updateRecoveryPasswordDirectly(String newPassword) async {
    final fallback = _recoveryPasswordFallback;
    if (fallback != null) {
      await fallback(newPassword);
      return;
    }
    await _requireClient().auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> _applyUser(User? user) async {
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
  emailVerificationRequired,
  passwordResetCodeSent,
  passwordRecoveryVerified,
  codeResent,
  failure,
}

class AuthActionResult {
  const AuthActionResult._(
    this.status, {
    this.message,
    this.errorCode,
    this.statusCode,
  });

  const AuthActionResult.authenticated()
    : this._(AuthActionStatus.authenticated);

  const AuthActionResult.emailVerificationRequired([String? message])
    : this._(AuthActionStatus.emailVerificationRequired, message: message);

  const AuthActionResult.passwordResetCodeSent([String? message])
    : this._(AuthActionStatus.passwordResetCodeSent, message: message);

  const AuthActionResult.passwordRecoveryVerified()
    : this._(AuthActionStatus.passwordRecoveryVerified);

  const AuthActionResult.codeResent([String? message])
    : this._(AuthActionStatus.codeResent, message: message);

  const AuthActionResult.failure(
    String message, {
    String? errorCode,
    int? statusCode,
  }) : this._(
         AuthActionStatus.failure,
         message: message,
         errorCode: errorCode,
         statusCode: statusCode,
       );

  final AuthActionStatus status;
  final String? message;
  final String? errorCode;
  final int? statusCode;
}
