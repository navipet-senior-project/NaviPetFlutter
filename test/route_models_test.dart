import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/data/travel_mode.dart';

const step = NavigationStep(
  instruction: 'Turn left onto Beach Drive',
  distanceMeters: 40,
  durationSeconds: 30,
  maneuver: NavigationCoordinate(latitude: 33.78, longitude: -118.11),
  maneuverType: 'turn',
  maneuverModifier: 'left',
);

const route = NavigationRoute(
  coordinates: [NavigationCoordinate(latitude: 33.78, longitude: -118.11)],
  steps: [step],
  distanceMeters: 320,
  durationSeconds: 260,
);

void main() {
  test('walking is the only enabled travel mode', () {
    expect(enabledTravelModes, [TravelMode.walking]);
    expect(TravelMode.walking.label, 'Walking');
    expect(TravelMode.walking.directionsProfile, 'walking');
  });

  test('a plan exposes its selected route', () {
    const plan = RoutePlan(routes: [route], mode: TravelMode.walking);

    expect(plan.selected, route);
    expect(plan.selectedIndex, 0);
  });

  test('selecting an alternate keeps the other fields', () {
    const other = NavigationRoute(
      coordinates: [NavigationCoordinate(latitude: 33.79, longitude: -118.12)],
      steps: [],
      distanceMeters: 500,
      durationSeconds: 400,
    );
    const plan = RoutePlan(
      routes: [route, other],
      mode: TravelMode.walking,
      endsAtBuilding: true,
    );

    final updated = plan.select(1);

    expect(updated.selected, other);
    expect(updated.selectedIndex, 1);
    expect(updated.endsAtBuilding, isTrue);
    expect(updated.mode, TravelMode.walking);
  });

  test('carries maneuver metadata on steps', () {
    expect(plan(route).selected.steps.single.maneuverType, 'turn');
    expect(plan(route).selected.steps.single.maneuverModifier, 'left');
  });
}

RoutePlan plan(NavigationRoute value) =>
    RoutePlan(routes: [value], mode: TravelMode.walking);
