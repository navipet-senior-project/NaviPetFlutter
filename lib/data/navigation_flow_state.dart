import 'campus_place.dart';
import 'navigation_models.dart';
import 'travel_mode.dart';

/// Where a route starts.
sealed class RouteOrigin {
  const RouteOrigin();

  NavigationCoordinate? get coordinate;

  String get label;

  /// Guidance is only offered when the route starts where the user is.
  bool get canStartGuidance;
}

class CurrentLocationOrigin extends RouteOrigin {
  const CurrentLocationOrigin({
    required NavigationCoordinate coordinate,
    this.approximate = false,
  })
    // ignore: prefer_initializing_formals
    : _coordinate = coordinate;

  final NavigationCoordinate _coordinate;
  final bool approximate;

  @override
  NavigationCoordinate? get coordinate => _coordinate;

  @override
  String get label => approximate ? 'Approximate location' : 'Your location';

  @override
  bool get canStartGuidance => true;
}

class PlaceOrigin extends RouteOrigin {
  const PlaceOrigin({required this.place});

  final NaviDestination place;

  @override
  NavigationCoordinate? get coordinate => place.coordinate;

  @override
  String get label => place.name;

  @override
  bool get canStartGuidance => false;
}

class UnknownOrigin extends RouteOrigin {
  const UnknownOrigin();

  @override
  NavigationCoordinate? get coordinate => null;

  @override
  String get label => 'Choose starting point';

  @override
  bool get canStartGuidance => false;
}

/// One state per thing the user can be doing. No boolean flags.
sealed class NavigationFlowState {
  const NavigationFlowState();
}

class FlowIdle extends NavigationFlowState {
  const FlowIdle();
}

class FlowSearching extends NavigationFlowState {
  const FlowSearching({
    this.query = '',
    this.pickingOrigin = false,
    this.configuringRoute,
  });

  final String query;

  /// True when the overlay is choosing a starting point rather than a
  /// destination.
  final bool pickingOrigin;

  /// The route configuration this search interrupted, when [pickingOrigin]
  /// is true. Picking a place restores it with the new origin instead of
  /// falling through to an ordinary [FlowPlacePreview] — otherwise the
  /// destination and mode being configured would be lost. Null for an
  /// ordinary destination search.
  final FlowConfiguringRoute? configuringRoute;
}

class FlowPlacePreview extends NavigationFlowState {
  const FlowPlacePreview({
    required this.place,
    required this.destination,
    this.previousQuery = '',
  });

  final CampusPlace place;

  /// Null when the campus record has no map pin yet.
  final NaviDestination? destination;

  final String previousQuery;

  bool get routable => destination != null;
}

class FlowConfiguringRoute extends NavigationFlowState {
  const FlowConfiguringRoute({
    required this.destination,
    required this.origin,
    required this.mode,
    this.place,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final TravelMode mode;
  final CampusPlace? place;
}

class FlowCalculatingRoute extends NavigationFlowState {
  const FlowCalculatingRoute({
    required this.destination,
    required this.origin,
    required this.mode,
    this.place,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final TravelMode mode;
  final CampusPlace? place;
}

class FlowRoutePreview extends NavigationFlowState {
  const FlowRoutePreview({
    required this.destination,
    required this.origin,
    required this.plan,
    this.place,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final RoutePlan plan;
  final CampusPlace? place;

  TravelMode get mode => plan.mode;
}

class FlowRouteSteps extends NavigationFlowState {
  const FlowRouteSteps({
    required this.destination,
    required this.origin,
    required this.plan,
    this.place,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final RoutePlan plan;
  final CampusPlace? place;
}

class FlowActiveNavigation extends NavigationFlowState {
  const FlowActiveNavigation({
    required this.destination,
    required this.origin,
    required this.plan,
    this.stepIndex = 0,
    this.place,
  });

  final NaviDestination destination;
  final RouteOrigin origin;
  final RoutePlan plan;
  final int stepIndex;
  final CampusPlace? place;
}

/// Reserved for the Unity/Multiset handoff. Unreachable until an indoor
/// navigation service is registered; nothing in this phase enters it.
class FlowIndoorHandoff extends NavigationFlowState {
  const FlowIndoorHandoff({required this.destination});

  final NaviDestination destination;
}

class FlowError extends NavigationFlowState {
  const FlowError({
    required this.message,
    required this.previous,
    this.retryable = true,
  });

  final String message;
  final NavigationFlowState previous;
  final bool retryable;
}
