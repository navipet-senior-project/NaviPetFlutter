import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    final result = await appState.signIn(email: email, password: password);
    if (!mounted) return;

    switch (result.status) {
      case AuthActionStatus.authenticated:
        context.go('/map');
      case AuthActionStatus.emailConfirmationRequired:
      case AuthActionStatus.passwordResetSent:
        break;
      case AuthActionStatus.failure:
        _showMessage(result.message ?? 'Authentication failed.');
    }
  }

  Future<void> _continueAsGuest() async {
    final result = await context.read<AppState>().continueAsGuest();
    if (!mounted) return;
    if (result.status == AuthActionStatus.authenticated) {
      context.go('/map');
    } else {
      _showMessage(
        result.message ??
            'Guest sign-in failed. Enable anonymous sign-ins in Supabase Auth.',
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email first.');
      return;
    }
    final result = await context.read<AppState>().sendPasswordReset(email);
    if (!mounted) return;
    _showMessage(
      result.status == AuthActionStatus.passwordResetSent
          ? 'Password reset email sent.'
          : result.message ?? 'Could not send the reset email.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.signInBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 408),
              child: Column(
                children: [
                  Image.asset(
                    'assets/mascot.png',
                    width: 176,
                    height: 176,
                    fit: BoxFit.contain,
                  ),
                  const Text(
                    'NaviPet',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your friendly journey companion',
                    style: TextStyle(fontSize: 14, color: AppColors.labelInk),
                  ),
                  const SizedBox(height: 28),
                  if (!appState.isSupabaseConfigured) ...[
                    _configurationNotice(),
                    const SizedBox(height: 16),
                  ],
                  _field(
                    label: 'EMAIL ADDRESS',
                    controller: _emailController,
                    icon: Icons.mail_outline,
                    hint: 'hello@navipet.com',
                    keyboardType: TextInputType.emailAddress,
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'PASSWORD',
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    hint: '••••••••',
                    obscure: !_showPassword,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: appState.isBusy ? null : _resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  _primaryButton(appState),
                  const SizedBox(height: 12),
                  _modeButton(appState),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: appState.isBusy || !appState.isSupabaseConfigured
                        ? null
                        : _continueAsGuest,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Continue as Guest'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'By signing in, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.inputBorder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _configurationNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber),
      ),
      child: const Text(
        'Supabase setup required: add SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY to .env.',
        style: TextStyle(fontSize: 12, color: AppColors.amberInk),
      ),
    );
  }

  Widget _primaryButton(AppState appState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: appState.isBusy || !appState.isSupabaseConfigured
            ? null
            : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
        ),
        child: appState.isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _modeButton(AppState appState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: appState.isBusy ? null : () => context.go('/register'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.amberInk,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
        label: const Text(
          'Create Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.labelInk,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: action,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            suffixIcon: trailing,
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
          ),
        ),
      ],
    );
  }
}
