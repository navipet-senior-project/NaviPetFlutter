import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../screens/account_settings_screen.dart';
import '../screens/ar_navigation_screen.dart';
import '../screens/checklist_screen.dart';
import '../screens/email_sent_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/map_screen.dart';
import '../screens/pet_customization_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/verify_email_screen.dart';

GoRouter createAppRouter(AppState appState) => GoRouter(
  initialLocation: appState.isAuthenticated ? '/map' : '/signin',
  refreshListenable: appState,
  redirect: (context, state) {
    final location = state.matchedLocation;
    final onPublicRoute = <String>{
      '/signin',
      '/register',
      '/verify-email',
      '/forgot-password',
      '/email-sent',
      '/reset-password',
    }.contains(location);

    if (location == '/reset-password' && !appState.hasPendingPasswordRecovery) {
      return '/forgot-password';
    }
    if (!appState.isAuthenticated && !onPublicRoute) return '/signin';
    if (appState.isAuthenticated && onPublicRoute) return '/map';
    return null;
  },
  routes: [
    GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => VerifyEmailScreen(
        email: state.uri.queryParameters['email'] ?? '',
        purpose: state.uri.queryParameters['purpose'] == 'recovery'
            ? VerificationPurpose.passwordRecovery
            : VerificationPurpose.registration,
      ),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/email-sent',
      builder: (context, state) =>
          EmailSentScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(
      path: '/pet',
      builder: (context, state) => const PetCustomizationScreen(),
    ),
    GoRoute(
      path: '/checklist',
      builder: (context, state) => const ChecklistScreen(),
    ),
    GoRoute(path: '/search', redirect: (context, state) => '/map'),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: '/ar',
      builder: (context, state) => const ArNavigationScreen(),
    ),
  ],
);
