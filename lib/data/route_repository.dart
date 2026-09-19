import 'navigation_models.dart';
import 'outdoor_route_gateway.dart';
import 'travel_mode.dart';

class RouteFailure implements Exception {
  const RouteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns a destination into a route plan the flow can present.
///
/// The backend has no routing endpoint, so this delegates to the Mapbox
/// Directions gateway. It is the only place that knows that.
class RouteRepository {
  RouteRepository({required this.gateway});

  final OutdoorRouteGateway gateway;

  Future<RoutePlan> plan({
    required NavigationCoordinate origin,
    required NaviDestination destination,
    TravelMode mode = TravelMode.walking,
  }) async {
    final NavigationRoute route;
    try {
      route = await gateway.getRoute(
        origin: origin,
        destination: destination.coordinate,
        profile: mode.directionsProfile,
      );
    } on Object catch (error) {
      throw RouteFailure(_messageFor(error));
    }

    final endsAtBuilding =
        destination.type == CampusDestinationType.room ||
        destination.isBuildingAlternative;
    final buildingLabel = destination.buildingCode ?? destination.name;

    return RoutePlan(
      routes: [route],
      mode: mode,
      endsAtBuilding: endsAtBuilding,
      warnings: [
        if (endsAtBuilding)
          'Walking guidance ends at $buildingLabel. Indoor directions are '
              'not available yet.',
      ],
    );
  }

  static String _messageFor(Object error) {
    final text = error.toString();
    if (text.toLowerCase().contains('no walkable route')) {
      return 'No walking route to that destination.';
    }
    return 'We could not build a route. Check your connection and try again.';
  }
}
