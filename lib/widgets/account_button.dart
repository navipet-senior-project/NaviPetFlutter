import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';

/// The same account entry point on the map, calendar, and pet screens.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.activeUser;
    return IconButton(
      tooltip: 'Account settings',
      onPressed: () => context.push('/account'),
      icon: ProfileAvatar(
        name: user?.name ?? '?',
        color: user?.avatarColor ?? AppColors.amber,
        imageUrl: user?.avatarUrl,
        size: 30,
        initialStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
        onImageError: state.reportAvatarLoadFailed,
      ),
    );
  }
}
