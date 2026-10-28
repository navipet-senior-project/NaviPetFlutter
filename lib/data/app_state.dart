import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_token_provider.dart';
import 'course_class.dart';
import 'classes_gateway.dart';
import 'email_change.dart';
import 'profile_gateway.dart';
import 'registration_gateway.dart';
import 'user_account.dart';

/// Outcome of [AppState.verifyAndToggleTask].
enum TaskClaimResult {
  claimed,
  notToday,
  sessionTooShort,
  locationUnavailable,
  tooFar,
}

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
    ProfileGateway? profileGateway,
    AuthTokenProvider? authTokenProvider,
    Future<void> Function()? sessionDiscarder,
  }) : this._(
         supabase,
         registrationGateway,
         verificationSessionHandler,
         signupCodeResender,
         recoverySessionRefresher,
         recoveryPasswordFallback,
         classesGateway,
         profileGateway,
         authTokenProvider,
         sessionDiscarder,
       );

  AppState._(
    this._supabase,
    this._registrationGateway,
    this._verificationSessionHandler,
    this._signupCodeResender,
    this._recoverySessionRefresher,
    this._recoveryPasswordFallback,
    this._classesGateway,
    this._profileGateway,
    this._authTokenProvider,
    this._sessionDiscarder,
  ) {
    if (_supabase == null) return;

    _applyUser(_supabase.auth.currentUser);
    _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      _applyUser(event.session?.user);
    });
  }

  final SupabaseClient? _supabase;
  final RegistrationGateway? _registrationGateway;
  final ClassesGateway? _classesGateway;
  final ProfileGateway? _profileGateway;
  final Future<void> Function(RegistrationVerificationSuccess tokens)?
  _verificationSessionHandler;
  final Future<void> Function(String email)? _signupCodeResender;
  final Future<RegistrationVerificationSuccess> Function(
    RegistrationVerificationSuccess tokens,
  )?
  _recoverySessionRefresher;
  final Future<void> Function(String newPassword)? _recoveryPasswordFallback;

  /// Source of the backend bearer token. Null falls back to the Supabase
  /// client's current session.
  final AuthTokenProvider? _authTokenProvider;

  /// Test seam for dropping the session; production signs out of Supabase.
  final Future<void> Function()? _sessionDiscarder;
  StreamSubscription<AuthState>? _authSubscription;
  RegistrationVerificationSuccess? _pendingRecoverySession;
  bool _passwordRecoveryInProgress = false;

  UserAccount? _activeUser;
  bool _busy = false;
  String? _errorMessage;
  List<CourseClass> _classes = const [];
  Set<String> _completionKeys = const {};
  Map<String, int> _completionCounts = const {};
  int _points = 0;
  Set<String> _ownedOutfits = const {};
  String? _equippedOutfit;
  bool _checkingNearbyTasks = false;
  bool _classesBusy = false;
  final Map<String, DateTime> _onlineSessionStarts = {};
  Future<void>? _profileFetch;
  String? _profileFetchUserId;
  DateTime? _profileFetchedAt;
  String? _avatarRetriedFor;
  DateTime? _avatarRetriedAt;
  static const _avatarRetryInterval = Duration(seconds: 30);

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
  int get points => _points;
  Set<String> get ownedOutfits => Set.unmodifiable(_ownedOutfits);
  String? get equippedOutfit => _equippedOutfit;
  bool get hasPendingPasswordRecovery => _pendingRecoverySession != null;

  /// Null when the backend is not configured.
  ProfileGateway? get profileGateway => _profileGateway;

  /// Guests cannot edit their avatar: the backend's behaviour for anonymous
  /// sessions is unverified.
  bool get canEditAvatar =>
      _profileGateway != null &&
      _activeUser != null &&
      !_activeUser!.isAnonymous;

  /// Guests have no email to change, and the change needs the backend.
  bool get canChangeEmail =>
      _registrationGateway != null &&
      _activeUser != null &&
      !_activeUser!.isAnonymous;

  /// Reloads the signed avatar URL from the backend. The URL expires after
  /// about an hour, so this runs on sign-in, token refresh, and app resume.
  /// [maxAge] skips the request when the last load is at least that recent.
  /// Failures keep the current URL; the initials avatar covers a missing one.
  Future<void> refreshProfile({Duration? maxAge}) {
    final user = _activeUser;
    if (_profileGateway == null || user == null || user.isAnonymous) {
      return Future.value();
    }
    final fetchedAt = _profileFetchedAt;
    if (maxAge != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < maxAge) {
      return Future.value();
    }
    final inFlight = _profileFetch;
    if (inFlight != null && _profileFetchUserId == user.id) return inFlight;
    late final Future<void> fetch;
    fetch = _fetchProfile(user.id).whenComplete(() {
      if (identical(_profileFetch, fetch)) _profileFetch = null;
    });
    _profileFetchUserId = user.id;
    return _profileFetch = fetch;
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final profile = await _profileGateway!.fetchProfile();
      final current = _activeUser;
      if (current == null || current.id != userId) return;
      _profileFetchedAt = DateTime.now();
      _activeUser = current.copyWith(
        avatarUrl: () => profile.avatarUrl,
        role: profile.role,
      );
      notifyListeners();
    } on Object {
      // The avatar is optional; sign-in and the rest of the profile do not
      // depend on it, and this runs unawaited.
    }
  }

  /// Called when the avatar image fails to load, most likely because its
  /// signed URL expired. Refetches at most once per URL and at most once per
  /// [_avatarRetryInterval], so a permanently broken URL cannot cause a
  /// refetch loop. Safe to call during build: it never notifies synchronously.
  void reportAvatarLoadFailed(String url) {
    if (url != _activeUser?.avatarUrl || url == _avatarRetriedFor) return;
    final now = DateTime.now();
    final last = _avatarRetriedAt;
    if (last != null && now.difference(last) < _avatarRetryInterval) return;
    _avatarRetriedFor = url;
    _avatarRetriedAt = now;
    unawaited(refreshProfile());
  }

  /// Saves profile edits through the backend and applies the response.
  /// Throws [ProfileApiException]; a 404 with [avatarUploadId] means that
  /// upload no longer exists.
  Future<void> saveProfile({
    String? displayName,
    String? avatarUploadId,
    String? role,
  }) async {
    final gateway = _profileGateway;
    final user = _activeUser;
    if (gateway == null || user == null) {
      throw StateError('Sign in before editing your profile.');
    }
    final profile = await gateway.updateProfile(
      displayName: displayName,
      avatarUploadId: avatarUploadId,
      role: role,
    );
    final current = _activeUser;
    if (current == null || current.id != user.id) return;
    final name = profile.displayName.trim();
    _profileFetchedAt = DateTime.now();
    _activeUser = current.copyWith(
      name: name.isEmpty ? null : name,
      avatarUrl: () => profile.avatarUrl,
      role: profile.role,
    );
    notifyListeners();
  }

  Duration onlineSessionDuration(String classId) {
    final started = _onlineSessionStarts[classId];
    return started == null ? Duration.zero : DateTime.now().difference(started);
  }

  Duration onlineSessionRequirement(CourseClass course) {
    final start = _timeMinutes(course.startTime);
    final end = _timeMinutes(course.endTime);
    final minutes = end - start;
    return Duration(minutes: minutes > 0 ? minutes : 15);
  }

  bool get hasRunningOnlineSession => _onlineSessionStarts.isNotEmpty;

  bool onlineSessionRunning(String classId) =>
      _onlineSessionStarts.containsKey(classId);

  void startOnlineSession(String classId) {
    _onlineSessionStarts[classId] ??= DateTime.now();
    notifyListeners();
  }

  void stopOnlineSession(String classId) {
    _onlineSessionStarts.remove(classId);
    notifyListeners();
  }

  List<DailyClassTask> dailyTasks([DateTime? day]) {
    final date = day ?? DateTime.now();
    final scheduled = _classes.where((course) => course.occursOn(date.weekday));
    final source = scheduled.isEmpty ? _classes.take(3) : scheduled;
    return source.map((course) {
      final kind = scheduled.isEmpty
          ? 'prepare'
          : course.isOnline
          ? 'attend_online'
          : 'attend';
      return DailyClassTask(
        course: course,
        kind: kind,
        label: kind == 'attend'
            ? 'Go to ${course.locationLabel} for ${course.courseCode}'
            : kind == 'attend_online'
            ? 'Attend ${course.courseCode} online'
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
      _classes = await _fetchClasses(client, user.id);
      // Task completions only live in Supabase, whichever source served the
      // classes, so they must load on both paths.
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
      await refreshPoints();
    } on ClassesApiException catch (error) {
      _errorMessage = error.message;
    } on PostgrestException catch (error) {
      _errorMessage = error.message;
    } finally {
      _classesBusy = false;
      notifyListeners();
    }
  }

  /// Loads classes through the NaviPet backend when it is configured and the
  /// user has a session, falling back to reading Supabase directly.
  Future<List<CourseClass>> _fetchClasses(
    SupabaseClient client,
    String userId,
  ) async {
    final gateway = _classesGateway;
    final token = client.auth.currentSession?.accessToken;
    if (gateway != null && token != null && token.isNotEmpty) {
      return gateway.listClasses(token);
    }
    final classRows = await client
        .from('classes')
        .select()
        .eq('user_id', userId)
        .order('start_time');
    return (classRows as List<dynamic>)
        .map((row) => CourseClass.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveClass(CourseClassInput input) async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before adding a class.');
    _classesBusy = true;
    notifyListeners();
    try {
      final gateway = _classesGateway;
      final token = client.auth.currentSession?.accessToken;
      if (gateway != null && token != null && token.isNotEmpty) {
        if (input.id == null) {
          await gateway.createClass(accessToken: token, input: input);
        } else {
          await gateway.updateClass(
            accessToken: token,
            classId: input.id!,
            input: input,
          );
        }
        await refreshClasses();
        return;
      }
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
    final token = client.auth.currentSession?.accessToken;
    final gateway = _classesGateway;
    if (gateway != null && token != null && token.isNotEmpty) {
      await gateway.deleteClass(accessToken: token, classId: id);
      await refreshClasses();
      return;
    }
    await client.from('classes').delete().eq('id', id);
    await refreshClasses();
  }

  Future<void> toggleTask(DailyClassTask task, DateTime date) async {
    if (task.done) return;
    if (task.kind == 'attend') {
      await verifyAndToggleTask(task, date);
      return;
    }
    await _requireClient().rpc(
      'claim_daily_task',
      params: {
        'p_class_id': task.course.id,
        'p_kind': task.kind,
        'p_latitude': null,
        'p_longitude': null,
      },
    );
    await refreshClasses();
  }

  Future<void> refreshPoints() async {
    final client = _supabase;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final wallet = await client
        .from('point_wallets')
        .select('balance, equipped_outfit')
        .eq('user_id', userId)
        .maybeSingle();
    final purchases = await client
        .from('outfit_purchases')
        .select('outfit_id')
        .eq('user_id', userId);
    final current = client.auth.currentUser?.id;
    if (current != userId) return;
    _points = (wallet?['balance'] as num?)?.toInt() ?? 0;
    _equippedOutfit = wallet?['equipped_outfit'] as String?;
    _ownedOutfits = (purchases as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['outfit_id'].toString())
        .toSet();
    notifyListeners();
  }

  Future<void> buyOutfit(String outfitId) async {
    await _requireClient().rpc('buy_outfit', params: {'p_outfit_id': outfitId});
    await refreshPoints();
  }

  Future<void> equipOutfit(String outfitId) async {
    if (!_ownedOutfits.contains(outfitId)) return;
    await _requireClient().rpc(
      'equip_outfit',
      params: {'p_outfit_id': outfitId},
    );
    _equippedOutfit = outfitId;
    notifyListeners();
  }

  /// Called periodically while the app is visible. The database repeats the
  /// distance and schedule checks before it credits any points.
  Future<void> completeNearbyTasks() async {
    if (_checkingNearbyTasks || _supabase?.auth.currentUser == null) return;
    final tasks = dailyTasks()
        .where((task) => task.kind == 'attend' && !task.done)
        .toList();
    if (tasks.isEmpty) return;
    _checkingNearbyTasks = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      var claimed = false;
      for (final task in tasks) {
        if (position.accuracy > 150 ||
            Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  task.course.latitude,
                  task.course.longitude,
                ) >
                150) {
          continue;
        }
        try {
          await _claimTask(task, position.latitude, position.longitude);
          claimed = true;
        } on PostgrestException {
          // A nearby class may not be in its check-in window yet.
        }
      }
      if (claimed) await refreshClasses();
    } on Object {
      // Location and network access are optional during foreground polling.
    } finally {
      _checkingNearbyTasks = false;
    }
  }

  Future<void> _claimTask(
    DailyClassTask task,
    double? latitude,
    double? longitude,
  ) async {
    await _requireClient().rpc(
      'claim_daily_task',
      params: {
        'p_class_id': task.course.id,
        'p_kind': task.kind,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  /// Claims a daily task after checking it may be claimed now: only on the
  /// day it belongs to, and for attendance, near the class building
  /// (in person) or after a long enough session (online). A completed task
  /// stays completed so points cannot be earned again.
  Future<TaskClaimResult> verifyAndToggleTask(
    DailyClassTask task,
    DateTime date,
  ) async {
    if (task.done) {
      return TaskClaimResult.claimed;
    }
    if (!_isSameDay(date, DateTime.now())) {
      return TaskClaimResult.notToday;
    }
    if (task.kind == 'attend_online') {
      if (onlineSessionDuration(task.course.id) <
          onlineSessionRequirement(task.course)) {
        return TaskClaimResult.sessionTooShort;
      }
      await toggleTask(task, date);
      stopOnlineSession(task.course.id);
      return TaskClaimResult.claimed;
    }
    if (task.kind != 'attend') {
      await toggleTask(task, date);
      return TaskClaimResult.claimed;
    }
    final Position position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return TaskClaimResult.locationUnavailable;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return TaskClaimResult.locationUnavailable;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } on Object {
      return TaskClaimResult.locationUnavailable;
    }
    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      task.course.latitude,
      task.course.longitude,
    );
    if (position.accuracy > 150 || meters > 150) return TaskClaimResult.tooFar;
    await _claimTask(task, position.latitude, position.longitude);
    await refreshClasses();
    return TaskClaimResult.claimed;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _timeMinutes(String value) {
    final parts = value.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (int.tryParse(parts.elementAt(1)) ?? 0);
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
    required String role,
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
          role: role,
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

  /// Asks the backend to send a six-digit code to [newEmail]. Also used to
  /// resend: there is no separate resend endpoint.
  Future<EmailChangeResult> requestEmailChange(String newEmail) async {
    _setBusy(true);
    try {
      final gateway = _requireRegistrationGateway();
      final email = normalizeEmail(newEmail);
      final token = await _currentAccessToken();
      if (token == null) {
        return _emailChangeFailure(
          _missingSessionError,
          EmailChangeStep.request,
        );
      }
      try {
        await gateway.requestEmailChange(accessToken: token, newEmail: email);
      } on RegistrationException catch (error) {
        if (error.code != 'INVALID_ACCESS_TOKEN') rethrow;
        // The stored token may simply have expired. Refresh once, retry once.
        final refreshed = await _currentAccessToken(forceRefresh: true);
        if (refreshed == null) rethrow;
        await gateway.requestEmailChange(
          accessToken: refreshed,
          newEmail: email,
        );
      }
      return const EmailChangeResult.codeSent();
    } on RegistrationException catch (error) {
      if (error.code == 'REAUTH_REQUIRED') {
        return const EmailChangeResult.reauthRequired();
      }
      return _emailChangeFailure(error, EmailChangeStep.request);
    } catch (_) {
      return _emailChangeFailure(
        _unexpectedEmailChangeError,
        EmailChangeStep.request,
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Signs in again with the current email and [password], stores that
  /// session, then retries the request with its access token.
  Future<EmailChangeResult> reauthenticateAndRequestEmailChange({
    required String newEmail,
    required String password,
  }) async {
    _setBusy(true);
    var step = EmailChangeStep.reauthenticate;
    try {
      final gateway = _requireRegistrationGateway();
      final tokens = await gateway.signIn(
        email: _activeUser?.email ?? '',
        password: password,
      );
      await _establishSession(tokens);
      step = EmailChangeStep.request;
      await gateway.requestEmailChange(
        accessToken: tokens.accessToken,
        newEmail: normalizeEmail(newEmail),
      );
      return const EmailChangeResult.codeSent();
    } on RegistrationException catch (error) {
      // REAUTH_REQUIRED straight after a password sign-in is reported as a
      // failure, never as another prompt, so the screen cannot loop.
      return _emailChangeFailure(error, step);
    } catch (_) {
      return _emailChangeFailure(_unexpectedEmailChangeError, step);
    } finally {
      _setBusy(false);
    }
  }

  /// Confirms the code sent to [newEmail] and replaces the stored session
  /// with the one the backend returns.
  Future<EmailChangeResult> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async {
    _setBusy(true);
    try {
      final result = await _requireRegistrationGateway().verifyEmailChangeCode(
        newEmail: normalizeEmail(newEmail),
        code: code,
      );
      // From here the email has changed and the code is spent. Every path
      // below must report success of the change itself.
      if (!isStandardSessionToken(result.tokens.accessToken)) {
        await _discardSession();
        return const EmailChangeResult.changedSignInRequired(
          emailChangeSignInNotice,
        );
      }
      try {
        await _establishSession(result.tokens);
      } catch (_) {
        await _discardSession();
        return const EmailChangeResult.changedSignInRequired(
          emailChangeSignInNotice,
        );
      }
      return EmailChangeResult.changed(result.message);
    } on RegistrationException catch (error) {
      return _emailChangeFailure(error, EmailChangeStep.verify);
    } catch (_) {
      return _emailChangeFailure(
        _unexpectedEmailChangeError,
        EmailChangeStep.verify,
      );
    } finally {
      _setBusy(false);
    }
  }

  static const _missingSessionError = RegistrationException(
    message: 'No active session.',
    statusCode: 401,
    code: 'INVALID_ACCESS_TOKEN',
  );

  static const _unexpectedEmailChangeError = RegistrationException(
    message: 'Unexpected error.',
    statusCode: 500,
  );

  EmailChangeResult _emailChangeFailure(
    RegistrationException error,
    EmailChangeStep step,
  ) => EmailChangeResult.failure(
    emailChangeErrorMessage(error, step),
    errorCode: error.code,
    statusCode: error.statusCode,
  );

  Future<String?> _currentAccessToken({bool forceRefresh = false}) async {
    final provider = _authTokenProvider;
    if (provider != null) return provider.token(forceRefresh: forceRefresh);
    final auth = _supabase?.auth;
    if (auth == null) return null;
    if (!forceRefresh) return auth.currentSession?.accessToken;
    final response = await auth.refreshSession();
    return response.session?.accessToken;
  }

  /// Drops the session without installing a replacement. Local state is
  /// cleared even when the sign-out call fails, because the caller has
  /// already decided this session must not be used.
  Future<void> _discardSession() async {
    try {
      final discard = _sessionDiscarder;
      if (discard != null) {
        await discard();
      } else {
        await _requireClient().auth.signOut();
      }
    } catch (_) {
      // Fall through to clearing local state.
    }
    _activeUser = null;
    _pendingRecoverySession = null;
    notifyListeners();
  }

  /// Revokes the backend session on a best-effort basis, then always clears
  /// local state so a backend failure never leaves the user signed in.
  Future<void> signOut() async {
    _setBusy(true);
    try {
      final gateway = _registrationGateway;
      if (gateway != null) {
        try {
          final token = await _currentAccessToken();
          if (token != null) await gateway.logout(accessToken: token);
        } catch (_) {
          // Best effort: the local session is discarded regardless.
        }
      }
      await _discardSession();
      _errorMessage = null;
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
      _resetProfileFetchState();
      _classes = const [];
      _completionKeys = const {};
      _completionCounts = const {};
      _points = 0;
      _ownedOutfits = const {};
      _equippedOutfit = null;
      notifyListeners();
      return;
    }

    // Authentication should never wait for optional profile or class queries.
    // User metadata gives the UI an immediate account while those records load.
    // Auth events for the same user (e.g. token refresh) keep the avatar so
    // it does not flash back to initials while the new URL loads.
    final previous = _activeUser;
    final sameUser = previous?.id == user.id;
    if (!sameUser) {
      _resetProfileFetchState();
      _points = 0;
      _ownedOutfits = const {};
      _equippedOutfit = null;
    }
    _activeUser = UserAccount.fromSupabase(
      user,
      avatarUrl: sameUser ? previous?.avatarUrl : null,
    );
    notifyListeners();
    unawaited(_hydrateUserProfile(user));
    unawaited(refreshClasses());
    unawaited(refreshProfile());
  }

  void _resetProfileFetchState() {
    _profileFetchedAt = null;
    _avatarRetriedFor = null;
    _avatarRetriedAt = null;
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
    // `profiles.avatar_path` is a storage path, not a URL; the avatar URL only
    // comes from the backend, so keep whichever one is already loaded.
    final hydrated = UserAccount.fromSupabase(
      user,
      profile: profile,
      avatarUrl: _activeUser?.id == user.id ? _activeUser?.avatarUrl : null,
    );
    _activeUser = hydrated.copyWith(
      role:
          hydrated.role ??
          (_activeUser?.id == user.id ? _activeUser?.role : null),
    );
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
