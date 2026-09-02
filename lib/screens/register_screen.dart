import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

/// Dedicated sign-up screen backed by the NaviPet backend's confirmation-email
/// registration flow (`AppState.signUp` -> `RegistrationGateway`).
///
/// Deliberately does not sign the user in or navigate to `/map` on success:
/// the backend never returns a session from `/auth/register`, so the user
/// stays signed out until they confirm their email and the Supabase deep
/// link (`navipet://auth-callback`) completes the session on this device.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _passwordHelper =
      'At least 8 characters, 1 number, and 1 special character';
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _digitPattern = RegExp(r'\d');
  static final _specialCharPattern = RegExp(r'[^A-Za-z0-9]');

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) => _emailPattern.hasMatch(value);

  bool _isValidPassword(String value) =>
      value.length >= 8 &&
      value.length <= 128 &&
      _digitPattern.hasMatch(value) &&
      _specialCharPattern.hasMatch(value);

  String? get _emailError {
    final value = _emailController.text.trim();
    if (value.isEmpty || _isValidEmail(value)) return null;
    return 'Enter a valid email address.';
  }

  String? get _confirmPasswordError {
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty || confirm == _passwordController.text) return null;
    return 'Passwords do not match.';
  }

  bool get _passwordMeetsRules => _isValidPassword(_passwordController.text);

  bool get _isFormValid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _isValidEmail(_emailController.text.trim()) &&
      _passwordMeetsRules &&
      _confirmPasswordController.text == _passwordController.text &&
      _confirmPasswordController.text.isNotEmpty &&
      _agreedToTerms;

  void _goToSignIn() => context.go('/signin');

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final result = await appState.signUp(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;

    switch (result.status) {
      case AuthActionStatus.emailConfirmationRequired:
        final email = Uri.encodeQueryComponent(_emailController.text.trim());
        context.go('/check-email?email=$email&purpose=signup');
      case AuthActionStatus.failure:
        setState(() {
          _statusMessage = result.message ?? 'Registration failed.';
          _statusIsError = true;
        });
      case AuthActionStatus.authenticated:
        context.go('/map');
      case AuthActionStatus.passwordResetSent:
      case AuthActionStatus.passwordRecoveryReady:
      case AuthActionStatus.passwordUpdated:
        break;
    }
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
        toolbarHeight: 48,
        leading: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: _goToSignIn,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 408),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.amber,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/mascot.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Join the pack! Fill out the details below to get started.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.labelInk,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_statusMessage != null) ...[
                    _statusBanner(),
                    const SizedBox(height: 8),
                  ],
                  _field(
                    label: 'First Name',
                    controller: _firstNameController,
                    hint: 'e.g. Elbee',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Last Name',
                    controller: _lastNameController,
                    hint: 'e.g. Shark',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Campus Email',
                    controller: _emailController,
                    hint: 'hello@navipet.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Password',
                    controller: _passwordController,
                    hint: '••••••••',
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.next,
                    helperText: _passwordHelper,
                    helperIsError:
                        _passwordController.text.isNotEmpty &&
                        !_passwordMeetsRules,
                    trailing: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    hint: '••••••••',
                    obscureText: !_showConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_isFormValid && !appState.isBusy) _submit();
                    },
                    errorText: _confirmPasswordError,
                    trailing: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _termsRow(),
                  const SizedBox(height: 20),
                  _submitButton(appState),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.labelInk,
                        ),
                      ),
                      TextButton(
                        onPressed: _goToSignIn,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner() {
    final color = _statusIsError ? AppColors.danger : AppColors.navy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(fontSize: 13, color: color),
      ),
    );
  }

  Widget _termsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreedToTerms,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'I agree to the Terms of Service and Privacy Policy',
            style: TextStyle(fontSize: 12, color: AppColors.labelInk),
          ),
        ),
      ],
    );
  }

  Widget _submitButton(AppState appState) {
    final enabled = _isFormValid && !appState.isBusy;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.45),
          padding: EdgeInsets.zero,
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
            : const Text(
                'Create account',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? errorText,
    String? helperText,
    bool helperIsError = false,
    Widget? trailing,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 3, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF18181B)),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          enableSuggestions: !obscureText,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF747B8B)),
            suffixIcon: trailing,
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFFF8F8)
                : const Color(0xFFF7F7F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: hasError ? AppColors.danger : AppColors.navy,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: AppColors.danger,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (helperText != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: helperIsError ? AppColors.danger : AppColors.labelInk,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    helperText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: helperIsError
                          ? AppColors.danger
                          : AppColors.labelInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
