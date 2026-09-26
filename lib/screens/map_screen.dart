import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_state.dart';
import '../data/mapbox_config.dart';
import '../data/navi_map_controller.dart' show MapboxNaviMapController;
import '../data/navigation_flow_controller.dart';
import '../data/navigation_flow_state.dart';
import '../data/navigation_models.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/place_preview_sheet.dart';
import '../widgets/route_preview_sheet.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/search_overlay.dart';
import '../widgets/travel_mode_selector.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.controller});

  /// Injected by widget tests; in the app it comes from the provider tree.
  final NavigationFlowController? controller;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const _lastLatitudeKey = 'last_location_latitude';
  static const _lastLongitudeKey = 'last_location_longitude';

  late final Future<void> _lastLocationReady;

  MapboxMap? _map;
  StreamSubscription<geo.Position>? _positionSubscription;
  geo.Position? _position;
  NavigationCoordinate? _lastKnownCoordinate;
  String? _locationMessage;

  late final NavigationFlowController _flow;
  bool _flowResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLocationReady = _loadLastKnownLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_flowResolved) return;
    _flow = widget.controller ?? context.read<NavigationFlowController>();
    _flowResolved = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flow.handleAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    // MapScreen remounts every time NaviBottomNav routes away and back
    // (e.g. to /checklist or /pet) while the flow itself — app-scoped —
    // keeps whatever state it was in. Detaching here means a route
    // calculation that lands after this point calls into nothing rather
    // than a MapboxNaviMapController wrapping this now-dead map.
    _flow.detachMap();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
    final routes = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    final markers = await mapboxMap.annotations.createPointAnnotationManager();

    // Hands the flow a live map and re-issues whatever the current state
    // should already be showing — necessary both on first launch (the flow
    // was built, in main.dart's initState, before this map existed) and on
    // every remount (the flow is app-scoped and outlives this MapScreen
    // instance; without the replay, a route sheet from before the remount
    // would claim a distance and duration over a blank map).
    await _flow.attachMap(
      MapboxNaviMapController(map: mapboxMap, routes: routes, markers: markers),
    );

    await _lastLocationReady;
    if (_flow.state is FlowIdle) await _centerOnBestKnownLocation();
    await _initializeLocation();
  }

  Future<void> _loadLastKnownLocation() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_lastLatitudeKey);
    final longitude = preferences.getDouble(_lastLongitudeKey);
    if (latitude == null || longitude == null) return;
    final coordinate = NavigationCoordinate(
      latitude: latitude,
      longitude: longitude,
    );
    _lastKnownCoordinate = coordinate;
    if (!mounted) return;
    // The flow's LocationService defaults to no remembered fix at all,
    // which leaves its approximate-origin fallback dead: a momentary GPS
    // dropout would show UnknownOrigin and the manual picker even while
    // this exact persisted coordinate is on screen. Only seeds the gap —
    // primeLastKnown never overwrites a fresher live fix.
    _flow.location.primeLastKnown(coordinate);
    setState(() {});
  }

  Future<void> _rememberPosition(geo.Position position) async {
    final coordinate = NavigationCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _lastKnownCoordinate = coordinate;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble(_lastLatitudeKey, coordinate.latitude),
      preferences.setDouble(_lastLongitudeKey, coordinate.longitude),
    ]);
  }

  Future<void> _initializeLocation() async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationMessage = permission == geo.LocationPermission.deniedForever
              ? 'Location is disabled for NaviPet. Enable it in Settings.'
              : 'Location permission is required for navigation.';
        });
        if (_flow.state is FlowIdle || _flow.state is FlowActiveNavigation) {
          await _centerOnBestKnownLocation();
        }
      }
      return;
    }
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() => _locationMessage = 'Turn on Location Services.');
        if (_flow.state is FlowIdle || _flow.state is FlowActiveNavigation) {
          await _centerOnBestKnownLocation();
        }
      }
      return;
    }

    await _map?.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: AppColors.amber.toARGB32(),
        showAccuracyRing: true,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
      ),
    );

    const settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    try {
      _position = await geo.Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _rememberPosition(_position!);
      if (mounted) {
        setState(() => _locationMessage = null);
        // A live GPS fix must not replace the route camera while a route is
        // being previewed. Active guidance intentionally follows the user;
        // idle mode may recenter normally.
        if (_flow.state is FlowIdle || _flow.state is FlowActiveNavigation) {
          await _centerOnUser();
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _locationMessage = 'Waiting for a GPS location…');
      }
    }

    _positionSubscription =
        geo.Geolocator.getPositionStream(locationSettings: settings).listen(
          (position) {
            _position = position;
            unawaited(_rememberPosition(position));
            if (mounted) setState(() => _locationMessage = null);
          },
          onError: (Object error) {
            if (mounted) setState(() => _locationMessage = error.toString());
          },
        );
  }

  Future<void> _centerOnUser({bool following = false}) async {
    final map = _map;
    final position = _position;
    if (map == null || position == null) return;
    await map.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: following ? 17.5 : 16,
        pitch: 0,
        bearing: following && position.heading >= 0 ? position.heading : 0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  Future<void> _centerOnBestKnownLocation() async {
    final map = _map;
    final coordinate = _position == null
        ? _lastKnownCoordinate
        : NavigationCoordinate(
            latitude: _position!.latitude,
            longitude: _position!.longitude,
          );
    if (map == null || coordinate == null) return;
    await map.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(coordinate.longitude, coordinate.latitude),
        ),
        zoom: 16,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        final state = flow.state;
        final padding = MediaQuery.paddingOf(context);
        final locationMessage = flow.locationNotice ?? _locationMessage;
        return PopScope(
          canPop: state is FlowIdle,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) flow.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.map,
            bottomNavigationBar: state is FlowActiveNavigation
                ? null
                : const NaviBottomNav(active: NaviTab.location),
            body: Stack(
              children: [
                _mapWidget(),
                if (state is FlowIdle) _searchBar(context, padding),
                if (locationMessage != null && state is! FlowSearching)
                  _locationBanner(padding, state, locationMessage),
                if (_showsRecenterButton(state))
                  _recenterButton(padding, state),
                if (state is FlowSearching)
                  Positioned.fill(child: SearchOverlay(controller: flow)),
                if (state is FlowPlacePreview)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PlacePreviewSheet(
                      state: state,
                      onDirections: flow.requestDirections,
                      onClose: flow.back,
                    ),
                  ),
                if (state is FlowConfiguringRoute)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _routeSetup(state, flow),
                  ),
                if (state is FlowCalculatingRoute) _calculating(),
                if (state is FlowRoutePreview)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: RoutePreviewSheet(
                      destination: state.destination,
                      origin: state.origin,
                      plan: state.plan,
                      expanded: false,
                      onPrimary: flow.startRoute,
                      onToggleSteps: flow.showSteps,
                      onModeChanged: flow.setMode,
                      onSelectRoute: flow.selectRoute,
                      onEditOrigin: () => flow.openSearch(pickingOrigin: true),
                    ),
                  ),
                if (state is FlowRouteSteps)
                  // Positioned(left: 0, right: 0, bottom: 0, child: ...) —
                  // the container the task brief suggested — gives its child
                  // an *unbounded* height (a Positioned only gets a bounded
                  // main-axis constraint from the Stack when both edges on
                  // that axis are pinned; with only `bottom` set here, height
                  // is unconstrained). RoutePreviewSheet's expanded step list
                  // is a Flexible(ListView) inside a mainAxisSize.min Column,
                  // which throws under an unbounded height. Positioned.fill +
                  // Align gives the FractionallySizedBox a bounded height to
                  // take 80% of instead.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.8,
                        child: RoutePreviewSheet(
                          destination: state.destination,
                          origin: state.origin,
                          plan: state.plan,
                          expanded: true,
                          onPrimary: flow.startRoute,
                          onToggleSteps: flow.hideSteps,
                          onModeChanged: flow.setMode,
                          onSelectRoute: flow.selectRoute,
                          onEditOrigin: () =>
                              flow.openSearch(pickingOrigin: true),
                        ),
                      ),
                    ),
                  ),
                if (state is FlowActiveNavigation)
                  _activeNavigation(state, flow, padding),
                if (state is FlowError) _error(state, flow),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mapWidget() {
    final initialCoordinate =
        _lastKnownCoordinate ??
        const NavigationCoordinate(latitude: csulbLat, longitude: csulbLng);
    return MapWidget(
      key: const ValueKey('navipet-map'),
      styleUri: mapboxStyle,
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(
            initialCoordinate.longitude,
            initialCoordinate.latitude,
          ),
        ),
        zoom: csulbZoom,
      ),
      onMapCreated: _onMapCreated,
    );
  }

  Widget _searchBar(BuildContext context, EdgeInsets padding) {
    final activeUser = context.watch<AppState>().activeUser;
    return Positioned(
      top: padding.top + AppSpacing.sm,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: SearchBarField(
        placeholder: 'Where to?',
        onPressed: _flow.openSearch,
        right: Semantics(
          label: 'Account settings',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/account'),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: _avatar(
                  activeUser?.name ?? '?',
                  activeUser?.avatarColor ?? AppColors.amber,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hidden whenever a full-screen surface (the search overlay, the
  /// calculating spinner, or the mostly-full-height steps sheet) already
  /// covers the map it would float over.
  bool _showsRecenterButton(NavigationFlowState state) =>
      state is! FlowSearching &&
      state is! FlowCalculatingRoute &&
      state is! FlowRouteSteps;

  Widget _recenterButton(EdgeInsets padding, NavigationFlowState state) {
    final double bottom;
    if (state is FlowActiveNavigation) {
      bottom = 142 + padding.bottom;
    } else if (state is FlowPlacePreview ||
        state is FlowConfiguringRoute ||
        state is FlowRoutePreview) {
      bottom = 294;
    } else {
      bottom = 24;
    }
    return Positioned(
      right: 16,
      bottom: bottom,
      child: Semantics(
        label: 'Center map on your location',
        button: true,
        child: FloatingActionButton.small(
          heroTag: 'recenter',
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          onPressed: _centerOnBestKnownLocation,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _locationBanner(
    EdgeInsets padding,
    NavigationFlowState state,
    String message,
  ) {
    final top = padding.top + (state is FlowActiveNavigation ? 112 : 80);
    return Positioned(
      left: 16,
      right: 16,
      top: top,
      child: Material(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      ),
    );
  }

  Widget _calculating() => Positioned.fill(
    child: ColoredBox(
      // Same navy scrim as before (0x3D002B5B), expressed as a token instead
      // of a new hex literal: 0x3D / 0xFF is ~24% opacity.
      color: AppColors.navy.withValues(alpha: 0x3D / 0xFF),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Text('Finding your walking route…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _routeSetup(
    FlowConfiguringRoute state,
    NavigationFlowController flow,
  ) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.navy),
              title: Text(state.origin.label),
              trailing: TextButton(
                onPressed: () => flow.openSearch(pickingOrigin: true),
                child: const Text('Change'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: AppColors.navy),
              title: Text(state.destination.name),
            ),
            const SizedBox(height: AppSpacing.md),
            TravelModeSelector(selected: state.mode, onChanged: flow.setMode),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: state.origin.coordinate == null
                    ? null
                    : flow.calculateRoute,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  state.origin.canStartGuidance
                      ? 'Start route'
                      : 'Preview route',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(FlowError state, NavigationFlowController flow) => Positioned(
    left: AppSpacing.lg,
    right: AppSpacing.lg,
    bottom: AppSpacing.xl,
    child: Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(child: Text(state.message)),
            if (state.retryable)
              TextButton(onPressed: flow.retry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );

  Widget _activeNavigation(
    FlowActiveNavigation state,
    NavigationFlowController flow,
    EdgeInsets padding,
  ) {
    final route = state.plan.selected;
    return Stack(
      children: [
        Positioned(
          top: padding.top + AppSpacing.sm,
          left: AppSpacing.md,
          right: AppSpacing.md,
          child: _instructionCard(route, state.stepIndex),
        ),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: padding.bottom + AppSpacing.md,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.accentSoft,
                    child: Icon(
                      Icons.directions_walk,
                      color: AppColors.amberInk,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.destination.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${route.durationLabel} · ${route.distanceLabel}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: flow.back,
                    child: const Text('Overview'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmEnd(flow),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmEnd(NavigationFlowController flow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this route?'),
        content: const Text('Guidance stops and the route stays on the map.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End route'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await flow.endRoute();
  }

  Widget _instructionCard(NavigationRoute route, int stepIndex) {
    final step = route.steps.isEmpty
        ? null
        : route.steps[stepIndex.clamp(0, route.steps.length - 1)];
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.navigation, color: AppColors.amber, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                step?.instruction ?? 'Follow the highlighted route',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Semantics(
              label: 'Cancel navigation',
              button: true,
              child: IconButton(
                tooltip: 'Cancel navigation',
                onPressed: () => _confirmEnd(_flow),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, Color color) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
