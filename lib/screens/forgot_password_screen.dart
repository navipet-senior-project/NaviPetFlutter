import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final _emailController = TextEditingController();
  String? _emailError;
  String? _requestError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() {
        _emailError = 'Enter a valid email address.';
        _requestError = null;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _requestError = null;
    });
    final result = await context.read<AppState>().requestPasswordReset(email);
    if (!mounted) return;
    if (result.status == AuthActionStatus.passwordResetCodeSent) {
      context.go(
        Uri(path: '/email-sent', queryParameters: {'email': email}).toString(),
      );
    } else {
      setState(() {
        _requestError = result.message ?? 'Could not send the reset code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.signInBg,
      appBar: AppBar(
        backgroundColor: AppColors.signInBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: appState.isBusy ? null : () => context.go('/signin'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 408),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 64, color: AppColors.navy),
                  const SizedBox(height: 20),
                  const Text(
                    'Forgot password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your account email and we’ll send a verification code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.labelInk),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const ValueKey('forgot-password-email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    onChanged: (_) => setState(() {
                      _emailError = null;
                      _requestError = null;
                    }),
                    onSubmitted: (_) {
                      if (!appState.isBusy) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'hello@navipet.com',
                      prefixIcon: const Icon(Icons.mail_outline),
                      errorText: _emailError,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_requestError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _requestError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: appState.isBusy ? null : _submit,
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
                        : const Text('Send verification code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
