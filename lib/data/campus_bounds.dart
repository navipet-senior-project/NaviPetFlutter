import 'campus_place.dart';
import 'navigation_models.dart';

/// Geographic limits of the CSULB campus.
///
/// NaviPet searches campus only. Anything outside these limits is dropped
/// before it reaches the UI, whether it came from the campus database or from
/// the backend's temporary Mapbox fallback.
///
/// TODO(navipet): confirm these limits against the official CSULB campus map
/// before release. They are deliberately tight; widening them re-admits the
/// off-campus results this filter exists to remove.
class CampusBounds {
  const CampusBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  static const csulb = CampusBounds(
    minLatitude: 33.7730,
    maxLatitude: 33.7905,
    minLongitude: -118.1250,
    maxLongitude: -118.1035,
  );

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool contains(NavigationCoordinate coordinate) =>
      coordinate.latitude >= minLatitude &&
      coordinate.latitude <= maxLatitude &&
      coordinate.longitude >= minLongitude &&
      coordinate.longitude <= maxLongitude;
}

/// Keeps only places NaviPet can honestly present as CSULB destinations.
///
/// A campus record without coordinates is kept: the place exists, it simply
/// has no map pin yet, and the place preview says so rather than hiding it.
List<CampusPlace> filterToCampus(
  List<CampusPlace> places, {
  CampusBounds bounds = CampusBounds.csulb,
}) {
  return places
      .where((place) {
        if (place.external || place.source == 'mapbox') return false;
        final coordinate = place.outdoorDestination;
        if (coordinate == null) return true;
        return bounds.contains(coordinate);
      })
      .toList(growable: false);
}
