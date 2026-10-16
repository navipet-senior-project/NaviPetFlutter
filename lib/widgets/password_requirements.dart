import 'package:flutter/material.dart';

class PasswordRules {
  const PasswordRules._();

  static bool hasValidLength(String value) =>
      value.length >= 8 && value.length <= 128;
  static bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  static bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  static bool hasNumber(String value) => RegExp(r'\d').hasMatch(value);
  static bool hasSpecialCharacter(String value) =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  static bool isValid(String value) =>
      hasValidLength(value) &&
      hasUppercase(value) &&
      hasLowercase(value) &&
      hasNumber(value) &&
      hasSpecialCharacter(value);
}

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.password,
    this.unmetColor,
  });

  final String password;

  /// Colour for unmet rules; defaults to grey. The sign-up screen passes its
  /// error red after a rejected submit.
  final Color? unmetColor;

  @override
  Widget build(BuildContext context) {
    final requirements = <(String, bool)>[
      ('8–128 characters', PasswordRules.hasValidLength(password)),
      ('One uppercase letter', PasswordRules.hasUppercase(password)),
      ('One lowercase letter', PasswordRules.hasLowercase(password)),
      ('One number', PasswordRules.hasNumber(password)),
      ('One special character', PasswordRules.hasSpecialCharacter(password)),
    ];

    return Semantics(
      label: 'Password requirements',
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final requirement in requirements)
            _Requirement(
              label: requirement.$1,
              satisfied: requirement.$2,
              unmetColor: unmetColor,
            ),
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.label,
    required this.satisfied,
    this.unmetColor,
  });

  final String label;
  final bool satisfied;
  final Color? unmetColor;

  @override
  Widget build(BuildContext context) {
    final color = satisfied
        ? Colors.green.shade700
        : unmetColor ?? Colors.grey.shade600;
    return Semantics(
      label: '$label: ${satisfied ? 'satisfied' : 'not satisfied'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              satisfied ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey(
                'password-requirement-${satisfied ? 'met' : 'unmet'}-$label',
              ),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
