import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/campus_bounds.dart';
import 'package:navipet/data/campus_place.dart';
import 'package:navipet/data/navigation_models.dart';

CampusPlace place({
  required String id,
  NavigationCoordinate? coordinate,
  bool external = false,
  String source = 'csulb',
}) => CampusPlace(
  id: id,
  type: CampusDestinationType.building,
  title: 'Place $id',
  subtitle: 'Subtitle',
  source: source,
  outdoorDestination: coordinate,
  external: external,
);

void main() {
  const onCampus = NavigationCoordinate(
    latitude: 33.78307046,
    longitude: -118.11456126,
  );
  const offCampus = NavigationCoordinate(
    latitude: 33.9416,
    longitude: -118.4085,
  );

  test('contains a known on-campus coordinate', () {
    expect(CampusBounds.csulb.contains(onCampus), isTrue);
  });

  test('rejects a coordinate far from campus', () {
    expect(CampusBounds.csulb.contains(offCampus), isFalse);
  });

  test('drops external results', () {
    final filtered = filterToCampus([
      place(id: 'a', coordinate: onCampus),
      place(id: 'b', coordinate: onCampus, external: true, source: 'mapbox'),
    ]);

    expect(filtered.map((item) => item.id), ['a']);
  });

  test('drops results whose coordinate is off campus', () {
    final filtered = filterToCampus([
      place(id: 'a', coordinate: onCampus),
      place(id: 'b', coordinate: offCampus),
    ]);

    expect(filtered.map((item) => item.id), ['a']);
  });

  test('keeps campus records that have no coordinate yet', () {
    final filtered = filterToCampus([place(id: 'a')]);

    expect(filtered.map((item) => item.id), ['a']);
  });
}
