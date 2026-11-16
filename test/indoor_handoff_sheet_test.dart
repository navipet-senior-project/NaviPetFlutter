import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_models.dart';
import 'package:navipet/widgets/indoor_handoff_sheet.dart';

NaviDestination _room(
  String floor, {
  String? indoorId,
  String buildingCode = 'VEC',
}) => NaviDestination(
  name: 'VEC $floor',
  address: 'Vivian Engineering Center',
  coordinate: const NavigationCoordinate(latitude: 33.783, longitude: -118.114),
  id: 'place-$floor',
  floorNumber: floor,
  roomNumber: floor,
  type: CampusDestinationType.room,
  buildingCode: buildingCode,
  indoorDestinationId: indoorId,
);

void main() {
  testWidgets('unscanned floor does not offer a scan', (tester) async {
    var scanned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorHandoffSheet(
            destination: _room('3'),
            padding: EdgeInsets.zero,
            onScan: () => scanned = true,
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Floor 3 is not scanned.'), findsOneWidget);
    expect(
      find.text('Direction to the room, not turn-by-turn.'),
      findsOneWidget,
    );
    expect(
      find.text('Stairs, elevators, and mobility routing are unavailable.'),
      findsOneWidget,
    );
    expect(find.textContaining('No saved door position'), findsNothing);
    expect(find.text('Scan AR'), findsNothing);
    expect(scanned, isFalse);
  });

  testWidgets('another building floor 1 does not offer VEC scanning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorHandoffSheet(
            destination: _room('1', buildingCode: 'HC'),
            padding: EdgeInsets.zero,
            onScan: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.text('Floor 1 is not scanned.'), findsOneWidget);
    expect(find.text('Scan AR'), findsNothing);
  });

  testWidgets('a saved indoor id does not say the floor is unscanned', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorHandoffSheet(
            destination: _room('1', indoorId: 'indoor-119'),
            padding: EdgeInsets.zero,
            onScan: () {},
            onBack: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('not scanned'), findsNothing);
    expect(find.textContaining('No saved door position'), findsNothing);
    expect(find.text('Scan AR'), findsOneWidget);
  });
}
