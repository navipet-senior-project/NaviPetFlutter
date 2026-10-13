import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/email_change.dart';
import '../theme/app_theme.dart';

/// Collects the new email address and, when the backend asks for it, the
/// account password. The email itself changes on the code screen.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({
    super.key,
    this.initialEmail = '',
    this.requirePassword = false,
  });

  /// Prefills the field when the user comes back from the code screen.
  final String initialEmail;

  /// Opens on the password step. Set when a resend on the code screen was
  /// rejected with REAUTH_REQUIRED.
  final bool requirePassword;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final _password = TextEditingController();
  late bool _needsPassword = widget.requirePassword;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    if (appState.isBusy) return;
    final email = normalizeEmail(_email.text);
    final invalid = validateNewEmail(
      email,
      currentEmail: appState.activeUser?.email ?? '',
    );
    if (invalid != null) {
      setState(() => _errorMessage = invalid);
      return;
    }
    if (_needsPassword && _password.text.isEmpty) {
      setState(() => _errorMessage = emailChangePasswordRequiredMessage);
      return;
    }
    setState(() => _errorMessage = null);

    final result = _needsPassword
        ? await appState.reauthenticateAndRequestEmailChange(
            newEmail: email,
            password: _password.text,
          )
        : await appState.requestEmailChange(email);
    if (!mounted) return;

    switch (result.status) {
      case EmailChangeStatus.codeSent:
        context.go(
          '/account/email/verify?email=${Uri.encodeQueryComponent(email)}',
        );
      case EmailChangeStatus.reauthRequired:
        setState(() {
          _needsPassword = true;
          _errorMessage = null;
        });
      case EmailChangeStatus.failure:
        setState(() => _errorMessage = result.message);
      case EmailChangeStatus.changed:
      case EmailChangeStatus.changedSignInRequired:
        break;
    }
  }

  void _goBack() => context.canPop() ? context.pop() : context.go('/account');

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentEmail = appState.activeUser?.email ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Change your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current email: $currentEmail',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.labelInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We'll send a six-digit code to the new address. Your "
                    'email changes only after you enter that code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.labelInk,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const ValueKey('change-email-field'),
                    controller: _email,
                    enabled: !appState.isBusy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: _needsPassword
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: _decoration('New email'),
                    onSubmitted: (_) {
                      if (!_needsPassword) _submit();
                    },
                  ),
                  if (_needsPassword) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'For your security, enter your password to continue.',
                      style: TextStyle(fontSize: 14, color: AppColors.labelInk),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('change-email-password-field'),
                      controller: _password,
                      enabled: !appState.isBusy,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      decoration: _decoration('Password').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _errorBanner(_errorMessage!),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const ValueKey('change-email-submit'),
                      onPressed: appState.isBusy ? null : _submit,
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
                              _needsPassword
                                  ? 'Confirm password and send code'
                                  : 'Send verification code',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.labelInk),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.navy, width: 2),
    ),
  );

  Widget _errorBanner(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.danger),
    ),
  );
}
