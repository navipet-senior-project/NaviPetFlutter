import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/navigation_models.dart';
import '../screens/account_settings_screen.dart';
import '../screens/auth_recovery_screens.dart';
import '../screens/checklist_screen.dart';
import '../screens/email_sent_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/map_screen.dart';
import '../screens/navigation_flow_screens.dart';
import '../screens/pet_customization_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/search_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/verify_email_screen.dart';

/// App navigation, the Flutter analog of the RN `RootNavigator`.
///
/// Sign-in uses `context.go('/map')` which replaces the stack. The shared
/// bottom-nav tabs (Map / Pet / Checklist) switch with `context.go`, while
/// overlay-style screens (Search, AR, Account) are opened with `context.push`
/// so their back arrow / X pops back to the caller — matching the Figma
/// prototype's user flow.
GoRouter createAppRouter(AppState appState) => GoRouter(
  initialLocation: appState.isAuthenticated ? '/map' : '/signin',
  refreshListenable: appState,
  redirect: (context, state) {
<<<<<<< Updated upstream
    final location = state.matchedLocation;
    final onPublicRoute = <String>{
      '/signin',
      '/register',
      '/forgot-password',
      '/check-email',
      '/verify-code',
      '/password-reset-success',
    }.contains(location);
    // A backend recovery session is not a Supabase session, so `/new-password`
    // has to be reachable while signed out. Pin the user there until the reset
    // finishes or the session is discarded.
    if (appState.hasPasswordRecoverySession) {
      return location == '/new-password' ? null : '/new-password';
    }
    if (appState.isAuthenticated &&
        appState.isPasswordRecovery &&
        location != '/new-password') {
      return '/new-password';
    }
    if (!appState.isAuthenticated && !onPublicRoute) return '/signin';
    if (appState.isAuthenticated &&
        (location == '/signin' ||
            location == '/register' ||
            location == '/forgot-password')) {
      return '/map';
    }
=======
    final onPublicRoute =
        state.matchedLocation == '/signin' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/verify-email' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/email-sent' ||
        state.matchedLocation == '/reset-password';
    if (!appState.isAuthenticated && !onPublicRoute) return '/signin';
    if (state.matchedLocation == '/reset-password' &&
        !appState.hasPendingPasswordRecovery) {
      return '/forgot-password';
    }
    if (appState.isAuthenticated && onPublicRoute) return '/map';
>>>>>>> Stashed changes
    return null;
  },
  routes: [
    GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
<<<<<<< Updated upstream
=======
      path: '/verify-email',
      builder: (context, state) => VerifyEmailScreen(
        email: state.uri.queryParameters['email'] ?? '',
        purpose: state.uri.queryParameters['purpose'] == 'recovery'
            ? VerificationPurpose.passwordRecovery
            : VerificationPurpose.registration,
      ),
    ),
    GoRoute(
>>>>>>> Stashed changes
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
<<<<<<< Updated upstream
      path: '/check-email',
      builder: (context, state) => CheckEmailScreen(
        email: state.uri.queryParameters['email'] ?? '',
        isPasswordRecovery: state.uri.queryParameters['purpose'] == 'recovery',
      ),
    ),
    GoRoute(
      path: '/verify-code',
      builder: (context, state) => VerificationCodeScreen(
        email: state.uri.queryParameters['email'] ?? '',
        isPasswordRecovery: state.uri.queryParameters['purpose'] == 'recovery',
      ),
    ),
    GoRoute(
      path: '/new-password',
      builder: (context, state) => const NewPasswordScreen(),
    ),
    GoRoute(
      path: '/password-reset-success',
      builder: (context, state) => const PasswordResetSuccessScreen(),
=======
      path: '/email-sent',
      builder: (context, state) =>
          EmailSentScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
>>>>>>> Stashed changes
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
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: '/account/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/account/manage',
      builder: (context, state) => const ManageAccountScreen(),
    ),
    GoRoute(
      path: '/account/accessibility',
      builder: (context, state) => const AccessibilityScreen(),
    ),
    GoRoute(
      path: '/account/privacy',
      builder: (context, state) => const PrivacyPermissionsScreen(),
    ),
    GoRoute(
      path: '/place-details',
      builder: (context, state) => DestinationDetailsScreen(
        destination: state.extra is NaviDestination
            ? state.extra! as NaviDestination
            : null,
      ),
    ),
    GoRoute(
      path: '/navigation/outdoor',
      builder: (context, state) => const OutdoorNavigationScreen(),
    ),
    GoRoute(
      path: '/navigation/off-route',
      builder: (context, state) => const OffRouteScreen(),
    ),
    GoRoute(
      path: '/navigation/campus-arrival',
      builder: (context, state) => const CampusArrivalScreen(),
    ),
    GoRoute(
      path: '/navigation/localize',
      builder: (context, state) => const LocalizationScreen(),
    ),
    GoRoute(
      path: '/navigation/indoor',
      builder: (context, state) => const IndoorNavigationScreen(),
    ),
    GoRoute(
      path: '/navigation/elevator',
      builder: (context, state) => const ElevatorTransitionScreen(),
    ),
    GoRoute(
      path: '/navigation/final',
      builder: (context, state) => const FinalArrivalScreen(),
    ),
    GoRoute(
      path: '/ar',
      builder: (context, state) => const LocalizationScreen(),
    ),
  ],
);
