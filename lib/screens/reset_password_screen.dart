import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/password_requirements.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _passwordError;
  String? _confirmError;
  String? _requestError;

  bool get _passwordIsValid => PasswordRules.isValid(_passwordController.text);
  bool get _passwordsMatch =>
      _confirmController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;
  bool get _canSubmit => _passwordIsValid && _passwordsMatch;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final validPassword = PasswordRules.isValid(password);
    if (!validPassword || password != confirm) {
      setState(() {
        _passwordError = validPassword
            ? null
            : 'Your password does not meet all requirements.';
        _confirmError = password == confirm ? null : 'Passwords do not match.';
        _requestError = null;
      });
      return;
    }

    setState(() {
      _passwordError = null;
      _confirmError = null;
      _requestError = null;
    });
    final result = await context.read<AppState>().resetPassword(
      newPassword: password,
      confirmPassword: confirm,
    );
    if (!mounted) return;
    if (result.status == AuthActionStatus.authenticated) {
      context.go('/map');
    } else {
      setState(() {
        _requestError = result.message ?? 'Could not reset the password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.signInBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 408),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.password_outlined,
                    size: 64,
                    color: AppColors.navy,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a strong password that meets every requirement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.labelInk),
                  ),
                  const SizedBox(height: 28),
                  _passwordField(
                    key: const ValueKey('new-password'),
                    label: 'New password',
                    controller: _passwordController,
                    obscure: !_showPassword,
                    error: _passwordError,
                    onToggle: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  const SizedBox(height: 10),
                  PasswordRequirements(password: _passwordController.text),
                  const SizedBox(height: 16),
                  _passwordField(
                    key: const ValueKey('confirm-new-password'),
                    label: 'Confirm new password',
                    controller: _confirmController,
                    obscure: !_showConfirm,
                    error: _confirmError,
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    onSubmitted: (_) {
                      if (!appState.isBusy) _submit();
                    },
                  ),
                  if (_requestError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _requestError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    TextButton(
                      onPressed: appState.isBusy
                          ? null
                          : () => context.go('/forgot-password'),
                      child: const Text('Request a new code'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: appState.isBusy || !_canSubmit ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text('Reset password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required String? error,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscure,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onChanged: (_) => setState(() {
        _passwordError = null;
        _confirmError =
            _confirmController.text.isNotEmpty &&
                _confirmController.text != _passwordController.text
            ? 'Passwords do not match.'
            : null;
        _requestError = null;
      }),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
