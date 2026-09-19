import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/widgets/campus_search_result_tile.dart';

Widget host(CampusPlace place) => MaterialApp(
  home: Scaffold(
    body: CampusSearchResultTile(place: place, onTap: () {}),
  ),
);

void main() {
  testWidgets('shows type, building, floor and distance', (tester) async {
    await tester.pumpWidget(
      host(
        const CampusPlace(
          id: '00000000-0000-4000-8000-000000000001',
          type: CampusDestinationType.room,
          title: 'VEC 404',
          subtitle: 'Vivian Engineering Center',
          source: 'csulb',
          buildingCode: 'VEC',
          floorNumber: '4',
          distanceMeters: 137,
          outdoorDestination: NavigationCoordinate(
            latitude: 33.7831,
            longitude: -118.1146,
          ),
        ),
      ),
    );

    expect(find.text('VEC 404'), findsOneWidget);
    expect(find.text('Vivian Engineering Center'), findsOneWidget);
    expect(find.text('Room · VEC · Floor 4 · 450 ft'), findsOneWidget);
  });

  testWidgets('never shows a navigation-capability line', (tester) async {
    await tester.pumpWidget(
      host(
        const CampusPlace(
          id: '00000000-0000-4000-8000-000000000002',
          type: CampusDestinationType.building,
          title: 'Vivian Engineering Center',
          subtitle: 'Engineering',
          source: 'csulb',
          buildingCode: 'VEC',
        ),
      ),
    );

    expect(find.textContaining('navigation'), findsNothing);
    expect(find.text('Building · VEC'), findsOneWidget);
  });

  testWidgets('keeps a per-type icon key', (tester) async {
    await tester.pumpWidget(
      host(
        const CampusPlace(
          id: '00000000-0000-4000-8000-000000000003',
          type: CampusDestinationType.parking,
          title: 'General Parking Lot G1',
          subtitle: 'Parking',
          source: 'csulb',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('campus-result-icon-parking')),
      findsOneWidget,
    );
  });
}
