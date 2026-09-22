import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/travel_mode.dart';
import 'package:navipet/widgets/route_preview_sheet.dart';

const destination = NaviDestination(
  name: 'Horn Center',
  address: 'HC',
  coordinate: NavigationCoordinate(
    latitude: 33.78307046,
    longitude: -118.11456126,
  ),
);

final plan = RoutePlan(
  routes: [
    NavigationRoute(
      coordinates: [
        NavigationCoordinate(latitude: 33.784, longitude: -118.115),
      ],
      steps: [
        NavigationStep(
          instruction: 'Walk north on Beach Drive',
          distanceMeters: 120,
          durationSeconds: 90,
          maneuver: NavigationCoordinate(latitude: 33.784, longitude: -118.115),
          maneuverType: 'depart',
        ),
        NavigationStep(
          instruction: 'Arrive at Horn Center',
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: NavigationCoordinate(latitude: 33.783, longitude: -118.114),
          maneuverType: 'arrive',
        ),
      ],
      distanceMeters: 320,
      durationSeconds: 260,
    ),
  ],
  mode: TravelMode.walking,
);

/// Mirrors what `RouteRepository.plan()` produces when the destination is a
/// room (`endsAtBuilding: true`): the same route as [plan] but with the
/// human-approved indoor-guidance warning attached.
final warningPlan = RoutePlan(
  routes: plan.routes,
  mode: TravelMode.walking,
  endsAtBuilding: true,
  warnings: const [
    'Walking guidance ends at Horn Center. Indoor directions are not '
        'available yet.',
  ],
);

const liveOrigin = CurrentLocationOrigin(
  coordinate: NavigationCoordinate(latitude: 33.784, longitude: -118.115),
);

Widget host({
  required RouteOrigin origin,
  bool expanded = false,
  RoutePlan? routePlan,
  VoidCallback? onPrimary,
  VoidCallback? onToggleSteps,
  ValueChanged<TravelMode>? onModeChanged,
  ValueChanged<int>? onSelectRoute,
  VoidCallback? onEditOrigin,
}) => MaterialApp(
  home: Scaffold(
    body: RoutePreviewSheet(
      destination: destination,
      origin: origin,
      plan: routePlan ?? plan,
      expanded: expanded,
      onPrimary: onPrimary ?? () {},
      onToggleSteps: onToggleSteps ?? () {},
      onModeChanged: onModeChanged ?? (_) {},
      onSelectRoute: onSelectRoute ?? (_) {},
      onEditOrigin: onEditOrigin ?? () {},
    ),
  ),
);

void main() {
  testWidgets('summarises time, distance and destination', (tester) async {
    await tester.pumpWidget(
      host(
        origin: const CurrentLocationOrigin(
          coordinate: NavigationCoordinate(
            latitude: 33.784,
            longitude: -118.115,
          ),
        ),
      ),
    );

    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('0.2 mi'), findsOneWidget);
    expect(find.text('Horn Center'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
  });

  testWidgets('says Start route from the live location', (tester) async {
    await tester.pumpWidget(
      host(
        origin: const CurrentLocationOrigin(
          coordinate: NavigationCoordinate(
            latitude: 33.784,
            longitude: -118.115,
          ),
        ),
      ),
    );

    expect(find.text('Start route'), findsOneWidget);
  });

  testWidgets('says Preview route for a chosen origin', (tester) async {
    await tester.pumpWidget(
      host(origin: const PlaceOrigin(place: destination)),
    );

    expect(find.text('Preview route'), findsOneWidget);
    expect(find.text('Start route'), findsNothing);
  });

  testWidgets('lists steps when expanded', (tester) async {
    await tester.pumpWidget(
      host(
        origin: const CurrentLocationOrigin(
          coordinate: NavigationCoordinate(
            latitude: 33.784,
            longitude: -118.115,
          ),
        ),
        expanded: true,
      ),
    );

    expect(find.text('Walk north on Beach Drive'), findsOneWidget);
    expect(find.text('Arrive at Horn Center'), findsOneWidget);
  });

  testWidgets('tapping the primary button fires onPrimary from a live '
      'location', (tester) async {
    var fired = 0;
    await tester.pumpWidget(host(origin: liveOrigin, onPrimary: () => fired++));

    await tester.tap(find.text('Start route'));

    expect(fired, 1);
  });

  testWidgets(
    'tapping the primary button still fires onPrimary when the origin '
    'cannot start guidance — it is a different action, not a dead button',
    (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        host(
          origin: const PlaceOrigin(place: destination),
          onPrimary: () => fired++,
        ),
      );

      await tester.tap(find.text('Preview route'));

      expect(fired, 1);
    },
  );

  testWidgets('tapping Steps fires onToggleSteps', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      host(origin: liveOrigin, onToggleSteps: () => fired++),
    );

    await tester.tap(find.text('Steps'));

    expect(fired, 1);
  });

  testWidgets('tapping Hide steps fires onToggleSteps when expanded', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(
      host(origin: liveOrigin, expanded: true, onToggleSteps: () => fired++),
    );

    await tester.tap(find.text('Hide steps'));

    expect(fired, 1);
  });

  testWidgets('tapping the mode chip fires onModeChanged with that mode', (
    tester,
  ) async {
    TravelMode? changedTo;
    await tester.pumpWidget(
      host(origin: liveOrigin, onModeChanged: (mode) => changedTo = mode),
    );

    await tester.tap(find.byType(ChoiceChip));

    expect(changedTo, TravelMode.walking);
  });

  testWidgets('tapping edit origin fires onEditOrigin', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      host(origin: liveOrigin, onEditOrigin: () => fired++),
    );

    await tester.tap(find.textContaining('From '));

    expect(fired, 1);
  });

  testWidgets(
    'renders the endsAtBuilding warning verbatim, without rewording it',
    (tester) async {
      await tester.pumpWidget(host(origin: liveOrigin, routePlan: warningPlan));

      expect(
        find.text(
          'Walking guidance ends at Horn Center. Indoor directions are not '
          'available yet.',
        ),
        findsOneWidget,
      );
    },
  );
}
