import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/navigation_flow_state.dart';
import 'package:navipet/data/navigation_models.dart';

const here = NavigationCoordinate(latitude: 33.784, longitude: -118.115);

const horn = NaviDestination(
  name: 'Horn Center',
  address: 'HC',
  coordinate: NavigationCoordinate(
    latitude: 33.78307046,
    longitude: -118.11456126,
  ),
);

void main() {
  test('a live-location origin can start guidance', () {
    const origin = CurrentLocationOrigin(coordinate: here);

    expect(origin.canStartGuidance, isTrue);
    expect(origin.coordinate, here);
    expect(origin.label, 'Your location');
  });

  test('an approximate origin is labelled and can still start guidance', () {
    const origin = CurrentLocationOrigin(coordinate: here, approximate: true);

    expect(origin.label, 'Approximate location');
    expect(origin.canStartGuidance, isTrue);
  });

  test('a chosen place origin only previews', () {
    const origin = PlaceOrigin(place: horn);

    expect(origin.canStartGuidance, isFalse);
    expect(origin.label, 'Horn Center');
    expect(origin.coordinate, horn.coordinate);
  });

  test('an unknown origin has no coordinate', () {
    const origin = UnknownOrigin();

    expect(origin.canStartGuidance, isFalse);
    expect(origin.coordinate, isNull);
    expect(origin.label, 'Choose starting point');
  });
}
