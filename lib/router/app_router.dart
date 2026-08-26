import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../screens/account_settings_screen.dart';
import '../screens/ar_navigation_screen.dart';
import '../screens/checklist_screen.dart';
import '../screens/map_screen.dart';
import '../screens/pet_customization_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_screen.dart';
import '../screens/sign_in_screen.dart';

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
    final onPublicRoute =
        state.matchedLocation == '/signin' || state.matchedLocation == '/register';
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
      path: '/ar',
      builder: (context, state) => const ArNavigationScreen(),
    ),
  ],
);
