import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/widgets/place_preview_sheet.dart';

const room = CampusPlace(
  id: '00000000-0000-4000-8000-000000000001',
  type: CampusDestinationType.room,
  title: 'VEC 404',
  subtitle: 'Vivian Engineering Center',
  source: 'csulb',
  buildingCode: 'VEC',
  roomNumber: '404',
  floorNumber: '4',
  outdoorDestination: NavigationCoordinate(
    latitude: 33.7831,
    longitude: -118.1146,
  ),
);

const unmapped = CampusPlace(
  id: '00000000-0000-4000-8000-000000000002',
  type: CampusDestinationType.building,
  title: 'Vivian Engineering Center',
  subtitle: 'Engineering',
  source: 'csulb',
  buildingCode: 'VEC',
);

Widget host(FlowPlacePreview state, {VoidCallback? onDirections}) =>
    MaterialApp(
      home: Scaffold(
        body: PlacePreviewSheet(
          state: state,
          onDirections: onDirections ?? () {},
          onClose: () {},
        ),
      ),
    );

void main() {
  testWidgets('separates building and room for a room destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(FlowPlacePreview(place: room, destination: room.toDestination())),
    );

    expect(find.text('VEC 404'), findsOneWidget);
    expect(find.text('Vivian Engineering Center · Floor 4'), findsOneWidget);
  });

  testWidgets('offers directions for a routable place', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        FlowPlacePreview(place: room, destination: room.toDestination()),
        onDirections: () => tapped = true,
      ),
    );

    await tester.tap(find.text('Directions'));

    expect(tapped, isTrue);
  });

  testWidgets('disables directions when the place has no pin', (tester) async {
    await tester.pumpWidget(
      host(const FlowPlacePreview(place: unmapped, destination: null)),
    );

    expect(
      find.text("We don't have a map pin for this place yet."),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
