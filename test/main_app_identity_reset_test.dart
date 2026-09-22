import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/user_account.dart';
import 'package:navipet/main.dart';
import 'package:navipet/screens/map_screen.dart';
import 'package:provider/provider.dart';

/// Overrides just enough of AppState to drive identity changes without a
/// real Supabase client — the same override pattern app_router_test.dart
/// already uses for auth-state overrides (isAuthenticated,
/// isPasswordRecovery, etc.).
class _SwitchableIdentityAppState extends AppState {
  String? _identity = 'user-a';

  @override
  bool get isAuthenticated => true;

  @override
  UserAccount? get activeUser => _identity == null
      ? null
      : UserAccount(
          id: _identity!,
          name: 'Test User',
          email: 'test@example.com',
          avatarColor: const Color(0xFF002B5B),
          gems: 0,
          level: 1,
        );

  void switchTo(String? identity) {
    _identity = identity;
    notifyListeners();
  }
}

void main() {
  setUpAll(() {
    // main.dart's real _buildFlow() reads MAPBOX_PUBLIC_TOKEN and
    // BACKEND_BASE_URL through dotenv (via mapboxPublicToken/AppConfig),
    // which throws NotInitializedError if dotenv.load() was never called —
    // normally done in main() before runApp(), which these tests bypass by
    // constructing NaviPetApp directly. An empty, isOptional load matches
    // main()'s own "missing .env is tolerated" behavior.
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  testWidgets(
    "signing out mid-route resets the flow so the next identity does not "
    "inherit the previous one's state",
    (tester) async {
      final appState = _SwitchableIdentityAppState();

      await tester.pumpWidget(NaviPetApp(appState: appState));
      await tester.pumpAndSettle();

      final flow = Provider.of<NavigationFlowController>(
        tester.element(find.byType(MapScreen)),
        listen: false,
      );

      // A pure state transition — no network involved — so this proves the
      // app-scoped flow really was mid-something before the identity
      // changed, not just already idle by coincidence.
      flow.openSearch();
      expect(flow.state, isA<FlowSearching>());

      appState.switchTo('user-b');
      await tester.pump();

      expect(flow.state, isA<FlowIdle>());
    },
  );

  testWidgets('an unrelated AppState change does not reset the flow', (
    tester,
  ) async {
    final appState = _SwitchableIdentityAppState();

    await tester.pumpWidget(NaviPetApp(appState: appState));
    await tester.pumpAndSettle();

    final flow = Provider.of<NavigationFlowController>(
      tester.element(find.byType(MapScreen)),
      listen: false,
    );

    flow.openSearch();
    expect(flow.state, isA<FlowSearching>());

    // Same identity — notifyListeners() fires (e.g. AppState's own busy
    // flag or classes changing) but the id hasn't, so the flow must be
    // left alone.
    appState.switchTo('user-a');
    await tester.pump();

    expect(flow.state, isA<FlowSearching>());
  });
}
