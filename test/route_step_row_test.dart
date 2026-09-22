import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/theme/app_theme.dart';
import 'package:navipet/widgets/route_step_row.dart';

const maneuverPoint = NavigationCoordinate(
  latitude: 33.784,
  longitude: -118.115,
);

NavigationStep step({
  String instruction = 'Turn',
  double distanceMeters = 120,
  String? maneuverType,
  String? maneuverModifier,
}) => NavigationStep(
  instruction: instruction,
  distanceMeters: distanceMeters,
  durationSeconds: 60,
  maneuver: maneuverPoint,
  maneuverType: maneuverType,
  maneuverModifier: maneuverModifier,
);

Widget host(NavigationStep step, {int index = 0, bool isDestination = false}) =>
    MaterialApp(
      home: Scaffold(
        body: RouteStepRow(
          step: step,
          index: index,
          isDestination: isDestination,
        ),
      ),
    );

void main() {
  testWidgets('uses the arrive icon for an arrive maneuver', (tester) async {
    await tester.pumpWidget(host(step(maneuverType: 'arrive')));

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });

  testWidgets('uses the depart icon for a depart maneuver', (tester) async {
    await tester.pumpWidget(host(step(maneuverType: 'depart')));

    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('uses a left-turn icon for left modifiers', (tester) async {
    await tester.pumpWidget(
      host(step(maneuverType: 'turn', maneuverModifier: 'sharp left')),
    );

    expect(find.byIcon(Icons.turn_left_rounded), findsOneWidget);
  });

  testWidgets('uses a right-turn icon for right modifiers', (tester) async {
    await tester.pumpWidget(
      host(step(maneuverType: 'turn', maneuverModifier: 'slight right')),
    );

    expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
  });

  testWidgets('uses a u-turn icon for the uturn modifier', (tester) async {
    await tester.pumpWidget(
      host(step(maneuverType: 'turn', maneuverModifier: 'uturn')),
    );

    expect(find.byIcon(Icons.u_turn_left_rounded), findsOneWidget);
  });

  testWidgets('falls back to a straight icon with no recognised modifier', (
    tester,
  ) async {
    await tester.pumpWidget(host(step(maneuverType: 'turn')));

    expect(find.byIcon(Icons.straight_rounded), findsOneWidget);
  });

  testWidgets('renders the step distance label', (tester) async {
    final s = step(distanceMeters: 120);
    await tester.pumpWidget(host(s));

    expect(find.text(s.distanceLabel), findsOneWidget);
  });

  testWidgets('a non-destination row uses the neutral marker colours', (
    tester,
  ) async {
    await tester.pumpWidget(host(step(maneuverType: 'depart')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.screenBg);

    final icon = tester.widget<Icon>(find.byIcon(Icons.my_location));
    expect(icon.color, AppColors.navy);
  });

  testWidgets('a destination row uses the accent marker colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(step(maneuverType: 'arrive'), isDestination: true),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, AppColors.accentSoft);

    final icon = tester.widget<Icon>(find.byIcon(Icons.flag_outlined));
    expect(icon.color, AppColors.amberInk);
  });
}
