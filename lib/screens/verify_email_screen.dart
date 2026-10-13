import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/email_change.dart';
import '../data/registration_gateway.dart';
import '../theme/app_theme.dart';

enum VerificationPurpose { registration, passwordRecovery, emailChange }

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.purpose = VerificationPurpose.registration,
  });

  final String email;
  final VerificationPurpose purpose;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  /// Supabase keeps an email-change code for an hour. Registration and
  /// recovery codes keep the shorter window this screen has always shown.
  static const _emailChangeLifetimeSeconds = 60 * 60;
  static const _defaultLifetimeSeconds = 3 * 60;

  /// The project may send 30 emails an hour across every flow, so a resend
  /// is held back after each send.
  static const _resendHoldSeconds = 60;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updatingCode = false;
  String? _errorMessage;
  String? _successMessage;
  Timer? _countdownTimer;
  // Both are set by _startCountdown, which initState calls before the first
  // build.
  int _secondsRemaining = 0;
  int _resendHoldRemaining = 0;

  String get _code => _controllers.map((controller) => controller.text).join();
  bool get _hasCompleteCode => RegExp(r'^\d{6}$').hasMatch(_code);
  bool get _isExpired => _secondsRemaining == 0;
  String get _countdownLabel =>
      '${(_secondsRemaining ~/ 60).toString()}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';
  bool get _isRecovery =>
      widget.purpose == VerificationPurpose.passwordRecovery;
  bool get _isEmailChange => widget.purpose == VerificationPurpose.emailChange;
  int get _otpLifetimeSeconds =>
      _isEmailChange ? _emailChangeLifetimeSeconds : _defaultLifetimeSeconds;
  String get _title => switch (widget.purpose) {
    VerificationPurpose.registration => 'Verify your email',
    VerificationPurpose.passwordRecovery => 'Verify reset code',
    VerificationPurpose.emailChange => 'Confirm your new email',
  };
  String get _submitLabel => switch (widget.purpose) {
    VerificationPurpose.registration => 'Verify and continue',
    VerificationPurpose.passwordRecovery => 'Verify reset code',
    VerificationPurpose.emailChange => 'Confirm new email',
  };
  String get _emailChangeLocation =>
      '/account/email?email=${Uri.encodeQueryComponent(widget.email)}';

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final lifetime = _otpLifetimeSeconds;
    final hold = _isEmailChange ? _resendHoldSeconds : 0;
    _secondsRemaining = lifetime;
    _resendHoldRemaining = hold;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining = (lifetime - timer.tick).clamp(0, lifetime);
        _resendHoldRemaining = (hold - timer.tick).clamp(0, hold);
        if (_secondsRemaining == 0) {
          timer.cancel();
          _successMessage = null;
          _errorMessage =
              'This verification code has expired. Request a new code.';
        }
      });
    });
  }

  void _onCodeChanged(int index, String value) {
    if (_updatingCode) return;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    _updatingCode = true;

    if (digits.length > 1) {
      for (
        var offset = 0;
        offset < digits.length && index + offset < 6;
        offset++
      ) {
        _controllers[index + offset].text = digits[offset];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
    } else {
      _controllers[index].text = digits;
      _controllers[index].selection = TextSelection.collapsed(
        offset: digits.length,
      );
      if (digits.isNotEmpty && index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    }

    _updatingCode = false;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_hasCompleteCode || widget.email.isEmpty || _isExpired) return;
    if (_isEmailChange) return _confirmEmailChange();
    final appState = context.read<AppState>();
    final result = _isRecovery
        ? await appState.verifyPasswordRecoveryCode(
            email: widget.email,
            code: _code,
          )
        : await appState.verifyRegistrationCode(
            email: widget.email,
            code: _code,
          );
    if (!mounted) return;

    switch (result.status) {
      case AuthActionStatus.authenticated:
        context.go('/map');
      case AuthActionStatus.passwordRecoveryVerified:
        context.go('/reset-password');
      case AuthActionStatus.failure:
        setState(() {
          _errorMessage = result.statusCode == 401
              ? 'That code is invalid or expired. Request a new code and try again.'
              : result.message ?? 'Verification failed.';
          _successMessage = null;
        });
      case AuthActionStatus.emailVerificationRequired:
      case AuthActionStatus.passwordResetCodeSent:
      case AuthActionStatus.codeResent:
        break;
    }
  }

  Future<void> _confirmEmailChange() async {
    final appState = context.read<AppState>();
    // Captured first: replacing or discarding the session can make the router
    // redirect and unmount this screen before the result is handled.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await appState.confirmEmailChange(
      newEmail: widget.email,
      code: _code,
    );

    switch (result.status) {
      case EmailChangeStatus.changed:
        router.go('/account');
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message ?? emailChangedFallbackMessage),
          ),
        );
      case EmailChangeStatus.changedSignInRequired:
        router.go('/signin');
        messenger.showSnackBar(
          SnackBar(content: Text(result.message ?? emailChangeSignInNotice)),
        );
      case EmailChangeStatus.failure:
        if (!mounted) return;
        setState(() {
          _errorMessage =
              result.message ??
              'We could not confirm the code. Please try again.';
          _successMessage = null;
        });
      case EmailChangeStatus.codeSent:
      case EmailChangeStatus.reauthRequired:
        break;
    }
  }

  Future<void> _resend() async {
    if (widget.email.isEmpty) return;
    if (_isEmailChange) return _resendEmailChange();
    final appState = context.read<AppState>();
    final result = _isRecovery
        ? await appState.resendPasswordRecoveryCode(widget.email)
        : await appState.resendRegistrationCode(widget.email);
    if (!mounted) return;

    if (result.status == AuthActionStatus.codeResent) {
      _restartAfterResend(result.message ?? 'A new code was sent.');
    } else {
      setState(() {
        _successMessage = null;
        _errorMessage = result.message ?? 'Could not resend the code.';
      });
    }
  }

  /// There is no resend endpoint for an email change: the request is sent
  /// again. A code already in the inbox stays valid if this fails.
  Future<void> _resendEmailChange() async {
    final appState = context.read<AppState>();
    final result = await appState.requestEmailChange(widget.email);
    if (!mounted) return;

    switch (result.status) {
      case EmailChangeStatus.codeSent:
        _restartAfterResend('A new code was sent.');
      case EmailChangeStatus.reauthRequired:
        // The password sign-in is good for ten minutes, the code for sixty.
        context.go('$_emailChangeLocation&reauth=1');
      case EmailChangeStatus.failure:
        setState(() {
          _successMessage = null;
          _errorMessage = result.message ?? 'Could not resend the code.';
        });
      case EmailChangeStatus.changed:
      case EmailChangeStatus.changedSignInRequired:
        break;
    }
  }

  void _restartAfterResend(String message) {
    _updatingCode = true;
    for (final controller in _controllers) {
      controller.clear();
    }
    _updatingCode = false;
    _focusNodes.first.requestFocus();
    setState(() {
      _startCountdown();
      _errorMessage = null;
      _successMessage = message;
    });
  }

  void _goBack() {
    if (_isEmailChange) return context.go(_emailChangeLocation);
    context.go(_isRecovery ? '/forgot-password' : '/register');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: appState.isBusy ? null : _goBack,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 408),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset('assets/mascot.png'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email.isEmpty
                        ? 'Go back and enter your email again.'
                        : 'Enter the six-digit code sent to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.labelInk,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _isExpired
                        ? 'Code expired — request a new one'
                        : 'Code expires in $_countdownLabel',
                    key: const ValueKey('otp-countdown'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isExpired ? AppColors.danger : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Six-digit verification code',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = ((constraints.maxWidth - 40) / 6)
                            .clamp(38.0, 50.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => _codeField(index, fieldWidth),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _messageBanner(_errorMessage!, isError: true),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    _messageBanner(_successMessage!),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          _hasCompleteCode &&
                              widget.email.isNotEmpty &&
                              !_isExpired &&
                              !appState.isBusy
                          ? _submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.navy.withValues(
                          alpha: 0.45,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: appState.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _submitLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: appState.isBusy || _resendHoldRemaining > 0
                        ? null
                        : _resend,
                    child: Text(
                      _resendHoldRemaining > 0
                          ? 'Resend code in ${_resendHoldRemaining}s'
                          : 'Resend Code',
                    ),
                  ),
                  if (_isEmailChange) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'No code? Check the address and your spam folder. A '
                      'code is only sent if the address can be used.',
                      key: ValueKey('email-change-hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.labelInk,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageBanner(String message, {bool isError = false}) {
    final color = isError ? AppColors.danger : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color),
      ),
    );
  }

  Widget _codeField(int index, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        key: ValueKey('verification-code-$index'),
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        keyboardType: TextInputType.number,
        textInputAction: index == 5
            ? TextInputAction.done
            : TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.navy, width: 2),
          ),
        ),
        onChanged: (value) => _onCodeChanged(index, value),
        onSubmitted: (_) {
          if (_hasCompleteCode && !_isExpired) _submit();
        },
      ),
    );
  }
}
