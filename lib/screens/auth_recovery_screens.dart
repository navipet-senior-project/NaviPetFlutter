import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';

final _authEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _attempted = false;
  String? _serverError;

  String? get _emailError {
    if (!_attempted) return null;
    if (!_authEmailPattern.hasMatch(_emailController.text.trim())) {
      return 'Please enter a valid email address.';
    }
    return _serverError;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _attempted = true;
      _serverError = null;
    });
    final email = _emailController.text.trim();
    if (!_authEmailPattern.hasMatch(email)) return;
    final result = await context.read<AppState>().sendPasswordReset(email);
    if (!mounted) return;
    if (result.status == AuthActionStatus.passwordResetSent) {
      context.go(
        '/check-email?email=${Uri.encodeQueryComponent(email)}&purpose=recovery',
      );
    } else {
      setState(() => _serverError = result.message ?? 'Unable to send code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SecurityHeader(onBack: () => context.go('/signin')),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE7E7E9)),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          children: [
                            const AuthStatusIcon(icon: Icons.lock_reset),
                            const SizedBox(height: 20),
                            const Text(
                              'Forgot your password?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter the email address associated with your account, and we’ll send you a verification code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.labelInk,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 30),
                            AuthTextField(
                              label: 'Campus Email',
                              controller: _emailController,
                              hint: 'you@csulb.edu',
                              prefixIcon: Icons.search,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              errorText: _emailError,
                              onChanged: (_) {
                                if (_attempted) setState(() => _serverError = null);
                              },
                              onSubmitted: (_) => _send(),
                            ),
                            const SizedBox(height: 28),
                            AuthPrimaryButton(
                              label: 'Send verification code',
                              trailingArrow: true,
                              busy: appState.isBusy,
                              onPressed: _send,
                            ),
                            const SizedBox(height: 18),
                            TextButton(
                              onPressed: () => context.go('/signin'),
                              child: const Text(
                                'Back to sign in',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({
    super.key,
    required this.email,
    required this.isPasswordRecovery,
  });

  final String email;
  final bool isPasswordRecovery;

  String get _query =>
      'email=${Uri.encodeQueryComponent(email)}&purpose=${isPasswordRecovery ? 'recovery' : 'signup'}';

  Future<void> _resend(BuildContext context) async {
    final result = await context.read<AppState>().resendVerificationCode(
      email: email,
      isPasswordRecovery: isPasswordRecovery,
    );
    if (!context.mounted) return;
    final succeeded = result.status == AuthActionStatus.passwordResetSent ||
        result.status == AuthActionStatus.emailConfirmationRequired;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded ? 'A new verification code was sent.' : result.message ?? 'Unable to resend email.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppState>().isBusy;
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SecurityHeader(
                    onBack: () => context.go(
                      isPasswordRecovery ? '/forgot-password' : '/register',
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE7E7E9)),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          children: [
                            const AuthStatusIcon(
                              icon: Icons.check_circle,
                              iconColor: Color(0xFF8A7200),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Check your email',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'We’ve sent a 6–digit verification code to ${email.isEmpty ? 'your email address' : email}. Please check your inbox and enter the code on the next screen.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.labelInk,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: 'Go to verification',
                              trailingArrow: true,
                              onPressed: email.isEmpty
                                  ? null
                                  : () => context.go('/verify-code?$_query'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: busy || email.isEmpty
                                  ? null
                                  : () => _resend(context),
                              child: const Text(
                                'Resend email',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({
    super.key,
    required this.email,
    required this.isPasswordRecovery,
  });

  final String email;
  final bool isPasswordRecovery;

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  late final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _error;

  String get _code => _controllers.map((controller) => controller.text).join();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() => _error = null);
    final result = await context.read<AppState>().verifyEmailCode(
      email: widget.email,
      code: _code,
      isPasswordRecovery: widget.isPasswordRecovery,
    );
    if (!mounted) return;
    if (result.status == AuthActionStatus.passwordRecoveryReady) {
      context.go('/new-password');
    } else if (result.status == AuthActionStatus.authenticated) {
      context.go(widget.isPasswordRecovery ? '/new-password' : '/map');
    } else {
      setState(() {
        _error = result.message ?? 'This code has expired. Request a new code.';
      });
    }
  }

  Future<void> _resend() async {
    final result = await context.read<AppState>().resendVerificationCode(
      email: widget.email,
      isPasswordRecovery: widget.isPasswordRecovery,
    );
    if (!mounted) return;
    final succeeded = result.status == AuthActionStatus.passwordResetSent ||
        result.status == AuthActionStatus.emailConfirmationRequired;
    setState(() => _error = succeeded ? null : result.message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(succeeded ? 'A new code was sent.' : 'Unable to resend code.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final maskedEmail = _maskEmail(widget.email);
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SecurityHeader(
                    onBack: () => context.go(
                      '/check-email?email=${Uri.encodeQueryComponent(widget.email)}&purpose=${widget.isPasswordRecovery ? 'recovery' : 'signup'}',
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Enter verification code',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6–digit code sent to\n$maskedEmail',
                    style: const TextStyle(
                      color: AppColors.labelInk,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(
                      widget.isPasswordRecovery ? '/forgot-password' : '/register',
                    ),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Use a different email',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) => _codeBox(index)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: appState.isBusy ? null : _resend,
                      child: const Text(
                        'Resend code',
                        style: TextStyle(color: AppColors.labelInk),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: 'Verify code',
                    busy: appState.isBusy,
                    onPressed: _code.length == 6 ? _verify : null,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeBox(int index) {
    return SizedBox(
      width: 49,
      height: 58,
      child: TextField(
        key: Key('verification-digit-$index'),
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (value) {
          setState(() => _error = null);
          if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
        },
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFFF9F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.navy, width: 2),
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}${List.filled(at - 1, '•').join()}${email.substring(at)}';
  }
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  // Mirrors the backend's rules so the API's 422 is the exception, not the norm.
  static const _minPasswordLength = 8;
  static const _maxPasswordLength = 128;

  bool get _hasLength =>
      _passwordController.text.length >= _minPasswordLength &&
      _passwordController.text.length <= _maxPasswordLength;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _matches => _passwordController.text == _confirmController.text;
  bool get _valid => _hasLength && _hasUppercase && _hasNumber && _matches && _confirmController.text.isNotEmpty;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    // A second submit with the same password comes back as a 422 even though
    // the first one succeeded, so never let one start while one is in flight.
    if (appState.isBusy) return;
    final result = await appState.updatePassword(_passwordController.text);
    if (!mounted) return;
    if (result.status == AuthActionStatus.passwordUpdated) {
      context.go('/password-reset-success');
      return;
    }
    // An expired or non-recovery session cannot be retried here — the reset has
    // to restart from the "Forgot password" screen.
    if (result.code == 'INVALID_ACCESS_TOKEN') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.message ??
                  'Your password reset session has expired. Request a new code.',
            ),
          ),
        );
      context.go('/forgot-password');
      return;
    }
    setState(() => _error = result.message ?? 'Unable to reset password.');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SecurityHeader(
                    onBack: () {
                      // Without dropping the recovery session the router would
                      // pin the user right back to this screen.
                      appState.discardPasswordRecovery();
                      context.go('/signin');
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create a new\npassword',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 31,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your new password must be different from\nyour previous password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.labelInk, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  AuthTextField(
                    label: 'New Password',
                    controller: _passwordController,
                    hint: 'Enter new password',
                    obscureText: !_showPassword,
                    maxLength: _maxPasswordLength,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _error = null),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    label: 'Confirm Password',
                    controller: _confirmController,
                    hint: 'Confirm new password',
                    obscureText: !_showConfirm,
                    maxLength: _maxPasswordLength,
                    textInputAction: TextInputAction.done,
                    errorText: _confirmController.text.isNotEmpty && !_matches ? 'Passwords do not match.' : null,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) { if (_valid && !appState.isBusy) _submit(); },
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Password must contain:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.labelInk)),
                        const SizedBox(height: 10),
                        _requirement('At least 8 characters', _hasLength),
                        _requirement('One uppercase letter', _hasUppercase),
                        _requirement('One number', _hasNumber),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Reset password',
                    busy: appState.isBusy,
                    onPressed: _valid ? _submit : null,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _requirement(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 15,
            color: met ? AppColors.yellow : AppColors.inputBorder,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.labelInk, fontSize: 14)),
        ],
      ),
    );
  }
}

class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SecurityHeader(onBack: () => context.go('/signin')),
                ),
                const SizedBox(height: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE7E7E9)),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Column(
                      children: [
                        const AuthStatusIcon(
                          icon: Icons.check,
                          iconColor: Colors.white,
                          backgroundColor: AppColors.navy,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Password reset\nsuccessfully',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 25,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You can now sign in with your new\npassword.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.labelInk, fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        AuthPrimaryButton(
                          label: 'Sign in  →',
                          onPressed: () => context.go('/signin'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
