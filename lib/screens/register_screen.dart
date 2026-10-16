import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/password_requirements.dart';

// Figma A-04 (Sign Up, validation errors) tokens. AppColors.danger is a
// different red (#D92D20), so these stay local until the auth screens share
// A-04 tokens.
const _a04Error = Color(0xFFBA1A1A);
const _a04Fill = Color(0xFFF3F3F4);
const _a04ErrorFill = Color(0x33FFDAD6);
const _a04LabelInk = Color(0xFF1A1C1C);

/// Dedicated sign-up screen backed by the NaviPet backend's email-code
/// registration flow (`AppState.signUp` -> `RegistrationGateway`).
///
/// Registration continues on `/verify-email`, where the six-digit code creates
/// a Supabase session through the backend's `/auth/verify-otp` endpoint.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;
  bool _submitAttempted = false;
  String? _role;
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

  String? _requiredError(TextEditingController controller, String message) =>
      _submitAttempted && controller.text.trim().isEmpty ? message : null;

  String? get _firstNameError =>
      _requiredError(_firstNameController, 'Enter your first name.');

  String? get _lastNameError =>
      _requiredError(_lastNameController, 'Enter your last name.');

  String? get _emailError {
    final value = _emailController.text.trim();
    if (value.isEmpty) {
      return _submitAttempted ? 'Enter your email address.' : null;
    }
    return _isValidEmail(value) ? null : 'Please enter a valid email address.';
  }

  String? get _passwordError =>
      _submitAttempted && _passwordController.text.isEmpty
      ? 'Enter a password.'
      : null;

  String? get _confirmPasswordError {
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) {
      return _submitAttempted ? 'Confirm your password.' : null;
    }
    return confirm == _passwordController.text
        ? null
        : 'Passwords do not match.';
  }

  String? get _roleError =>
      _submitAttempted && _role == null ? 'Select a role.' : null;

  String? get _termsError => _submitAttempted && !_agreedToTerms
      ? 'Agree to the Terms to continue.'
      : null;

  bool get _passwordMeetsRules =>
      PasswordRules.isValid(_passwordController.text);

  bool get _isFormValid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _isValidEmail(_emailController.text.trim()) &&
      _passwordMeetsRules &&
      _confirmPasswordController.text == _passwordController.text &&
      _confirmPasswordController.text.isNotEmpty &&
      _role != null &&
      _agreedToTerms;

  void _goToSignIn() => context.go('/signin');

  void _goToVerification() {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _statusMessage = 'Enter your email address to verify its code.';
        _statusIsError = true;
      });
      return;
    }
    context.go(
      Uri(path: '/verify-email', queryParameters: {'email': email}).toString(),
    );
  }

  void _attemptSubmit() {
    setState(() => _submitAttempted = true);
    if (_isFormValid) _submit();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final result = await appState.signUp(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _role!,
    );
    if (!mounted) return;

    switch (result.status) {
      case AuthActionStatus.emailVerificationRequired:
        final email = _emailController.text.trim();
        context.go(
          Uri(
            path: '/verify-email',
            queryParameters: {'email': email},
          ).toString(),
        );
      case AuthActionStatus.failure:
        setState(() {
          _statusMessage = result.message ?? 'Registration failed.';
          _statusIsError = true;
        });
      case AuthActionStatus.authenticated:
      case AuthActionStatus.passwordResetCodeSent:
      case AuthActionStatus.passwordRecoveryVerified:
      case AuthActionStatus.codeResent:
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
                    errorText: _firstNameError,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Last Name',
                    controller: _lastNameController,
                    hint: 'e.g. Shark',
                    textInputAction: TextInputAction.next,
                    errorText: _lastNameError,
                  ),
                  const SizedBox(height: 16),
                  _label('Role'),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('registration-role'),
                    initialValue: _role,
                    hint: const Text(
                      'Select a role',
                      style: TextStyle(fontSize: 16, color: Color(0xFF747B8B)),
                    ),
                    decoration: _inputDecoration(hasError: _roleError != null),
                    items: const [
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Student'),
                      ),
                      DropdownMenuItem(
                        value: 'professor',
                        child: Text('Professor'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _role = value),
                  ),
                  if (_roleError case final error?) _errorLine(error),
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
                    errorText: _passwordError,
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
                  const SizedBox(height: 6),
                  PasswordRequirements(
                    password: _passwordController.text,
                    unmetColor: _submitAttempted ? _a04Error : null,
                  ),
                  const SizedBox(height: 6),
                  _field(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    hint: '••••••••',
                    obscureText: !_showConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!appState.isBusy) _attemptSubmit();
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
                  if (_termsError case final error?) _errorLine(error),
                  const SizedBox(height: 20),
                  _submitButton(appState),
                  TextButton(
                    onPressed: appState.isBusy ? null : _goToVerification,
                    child: const Text('Already have a verification code?'),
                  ),
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: appState.isBusy ? null : _attemptSubmit,
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
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
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
          decoration: _inputDecoration(
            hasError: errorText != null,
            hint: hint,
            suffix: trailing,
          ),
        ),
        if (errorText != null) _errorLine(errorText),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required bool hasError,
    String? hint,
    Widget? suffix,
  }) {
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
    final idleBorder = outline(hasError ? _a04Error : Colors.transparent);
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF747B8B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: hasError ? _a04ErrorFill : _a04Fill,
      border: idleBorder,
      enabledBorder: idleBorder,
      focusedBorder: outline(hasError ? _a04Error : AppColors.navy),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.48,
        color: _a04LabelInk,
      ),
    ),
  );

  Widget _errorLine(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 4),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 11.67, color: _a04Error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _a04Error,
            ),
          ),
        ),
      ],
    ),
  );
}
