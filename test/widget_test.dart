import 'package:flutter_test/flutter_test.dart';

import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/navigation_models.dart';

void main() {
  group('AppState without backend configuration', () {
    test('starts signed out and reports missing Supabase configuration', () {
      final state = AppState();
      addTearDown(state.dispose);

      expect(state.isSupabaseConfigured, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.activeUser, isNull);
    });

    test('returns a useful failure instead of pretending to sign in', () async {
      final state = AppState();
      addTearDown(state.dispose);

      final result = await state.signIn(
        email: 'person@example.com',
        password: 'password',
      );

      expect(result.status, AuthActionStatus.failure);
      expect(result.message, contains('Supabase is not configured'));
    });

    test(
      'reports missing signup configuration instead of a generic error',
      () async {
        final state = AppState();
        addTearDown(state.dispose);

        final result = await state.signUp(
          firstName: 'Elbee',
          lastName: 'Shark',
          email: 'person@example.com',
          password: 'Password1!',
        );

        expect(result.status, AuthActionStatus.failure);
        expect(result.message, contains('Supabase is not configured'));
        expect(result.message, isNot(contains('Something went wrong')));
      },
    );
  });

  group('NavigationRoute labels', () {
    test('formats a short walking route', () {
      const route = NavigationRoute(
        coordinates: [],
        steps: [],
        distanceMeters: 30,
        durationSeconds: 301,
      );

      expect(route.distanceLabel, '98 ft');
      expect(route.durationLabel, '6 min');
    });

    test('formats a longer route', () {
      const route = NavigationRoute(
        coordinates: [],
        steps: [],
        distanceMeters: 3218.688,
        durationSeconds: 3900,
      );

      expect(route.distanceLabel, '2.0 mi');
      expect(route.durationLabel, '1 hr 5 min');
    });
  });

  group('NavigationTripSummary labels', () {
    test('formats elapsed time and walking steps', () {
      const summary = NavigationTripSummary(
        elapsed: Duration(minutes: 12, seconds: 8),
        walkingSteps: 1342,
      );

      expect(summary.elapsedLabel, '12m 8s');
      expect(summary.walkingSteps, 1342);
      expect(summary.walkingStepsLabel, '1342');
    });

    test('reports unavailable steps when the device cannot count them', () {
      const summary = NavigationTripSummary(
        elapsed: Duration(seconds: 4),
        walkingSteps: null,
      );

      expect(summary.walkingStepsLabel, 'Unavailable');
    });
  });
}
