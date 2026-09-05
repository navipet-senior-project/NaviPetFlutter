import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

enum VerificationPurpose { registration, passwordRecovery }

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
  static const _otpLifetimeSeconds = 3 * 60;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updatingCode = false;
  String? _errorMessage;
  String? _successMessage;
  Timer? _countdownTimer;
  int _secondsRemaining = _otpLifetimeSeconds;

  String get _code => _controllers.map((controller) => controller.text).join();
  bool get _hasCompleteCode => RegExp(r'^\d{6}$').hasMatch(_code);
  bool get _isExpired => _secondsRemaining == 0;
  String get _countdownLabel =>
      '${(_secondsRemaining ~/ 60).toString()}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';
  bool get _isRecovery =>
      widget.purpose == VerificationPurpose.passwordRecovery;

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
    _secondsRemaining = _otpLifetimeSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining = (_otpLifetimeSeconds - timer.tick).clamp(
          0,
          _otpLifetimeSeconds,
        );
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

  Future<void> _resend() async {
    if (widget.email.isEmpty) return;
    final appState = context.read<AppState>();
    final result = _isRecovery
        ? await appState.resendPasswordRecoveryCode(widget.email)
        : await appState.resendRegistrationCode(widget.email);
    if (!mounted) return;

    if (result.status == AuthActionStatus.codeResent) {
      _updatingCode = true;
      for (final controller in _controllers) {
        controller.clear();
      }
      _updatingCode = false;
      _focusNodes.first.requestFocus();
      setState(() {
        _startCountdown();
        _errorMessage = null;
        _successMessage = result.message ?? 'A new code was sent.';
      });
    } else {
      setState(() {
        _successMessage = null;
        _errorMessage = result.message ?? 'Could not resend the code.';
      });
    }
  }

  void _goBack() => context.go(_isRecovery ? '/forgot-password' : '/register');

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
                    _isRecovery ? 'Verify reset code' : 'Verify your email',
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
                              _isRecovery
                                  ? 'Verify reset code'
                                  : 'Verify and continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: appState.isBusy ? null : _resend,
                    child: const Text('Resend Code'),
                  ),
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
