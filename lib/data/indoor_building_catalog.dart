import 'navigation_models.dart';

/// Identity and campus anchor shared by VEC's Mapbox directory entry and its
/// Unity indoor map. The anchor is a campus POI coordinate; it is not a
/// survey-grade building footprint.
abstract final class IndoorBuildingCatalog {
  static const vecBuildingCode = 'VEC';
  static const vecDisplayName = 'Vivian Engineering Center';
  static const vecMapSetCode = 'MSET_XTBY7AM7ZK77';
  static const vecMapFrame = 'multiset-mapset';
  static const vecAnchor = NavigationCoordinate(
    latitude: 33.783,
    longitude: -118.111,
  );
  static const vecHitRadiusMeters = 55.0;
}
