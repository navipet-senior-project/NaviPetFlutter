import 'navigation_models.dart';

/// Build flag: `--dart-define=NAVIPET_OUTDOOR_AR=true`. Set it only when the
/// private Unity library includes the outdoor Geospatial scene. Off, the
/// outdoor AR control explains that guidance is unavailable and opens nothing.
const outdoorArBuildEnabled = bool.fromEnvironment('NAVIPET_OUTDOOR_AR');

/// One outdoor ARCore Geospatial session toward the active route's
/// destination. It rides the indoor AR channel and gets the same result
/// envelope back; `mode` tells Unity which scene to run.
///
/// Carries no MultiSet token and no Google credential: Unity authorises with
/// the ARCore API itself.
class OutdoorArRequest {
  OutdoorArRequest.to(NaviDestination destination)
    : name = destination.name,
      coordinate = destination.routingCoordinate;

  static const schemaVersion = 2;
  static const outdoorMode = 'outdoor';

  final String name;

  /// WGS84, the point the walking route itself ends at.
  final NavigationCoordinate coordinate;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'mode': outdoorMode,
    'destination': {
      'name': name,
      'latitude': coordinate.latitude,
      'longitude': coordinate.longitude,
    },
    // The host shows Google's ARCore notice and launches only after consent.
    'dataUseAccepted': true,
  };
}
