import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mapbox_config.dart';
import '../data/navi_map_controller.dart' show MapboxNaviMapController;
import '../data/navigation_flow_controller.dart';
import '../data/navigation_flow_state.dart';
import '../data/navigation_models.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/place_preview_sheet.dart';
import '../widgets/account_button.dart';
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
  String _mapStyle = mapboxStyle;
  static bool _remembered3d = false;
  static bool _rememberedRaisedBuildings = true;

  late final Future<void> _lastLocationReady;

  MapboxMap? _map;
  CameraViewportState? _initialMapViewport;
  MapboxNaviMapController? _naviMap;
  bool _is3d = false;
  bool _raisedBuildings = true;
  bool _bicycling = false;
  String? _styleBeforeBicycling;
  StreamSubscription<geo.Position>? _positionSubscription;
  geo.Position? _position;
  NavigationCoordinate? _lastKnownCoordinate;
  String? _locationMessage;

  late final NavigationFlowController _flow;
  bool _flowResolved = false;

  @override
  void initState() {
    super.initState();
    _is3d = _remembered3d;
    _raisedBuildings = _rememberedRaisedBuildings;
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
      unawaited(_refreshLivePosition());
    }
  }

  Future<void> _refreshLivePosition() async {
    if (_flow.state is! FlowActiveNavigation) return;
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
        ),
      );
      if (!mounted) return;
      _position = position;
      await _passLivePosition(position);
    } on Object {
      // The existing stream and location banner handle a temporarily lost fix.
    }
  }

  Future<void> _passLivePosition(geo.Position position) async {
    if (_flow.state is! FlowActiveNavigation) return;
    await _flow.onLiveLocation(
      NavigationCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      accuracyMeters: position.accuracy,
      bearing: position.heading,
      timestamp: position.timestamp,
    );
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
    // Created first so the building outline draws under routes and pins.
    final footprints = await mapboxMap.annotations
        .createPolygonAnnotationManager();
    final routes = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    final markers = await mapboxMap.annotations.createPointAnnotationManager();
    await markers.setTextAllowOverlap(true);
    final arrowMarkers = await mapboxMap.annotations
        .createPointAnnotationManager();
    await arrowMarkers.setTextRotationAlignment(TextRotationAlignment.MAP);
    await arrowMarkers.setTextAllowOverlap(true);

    // Hands the flow a live map and re-issues whatever the current state
    // should already be showing — necessary both on first launch (the flow
    // was built, in main.dart's initState, before this map existed) and on
    // every remount (the flow is app-scoped and outlives this MapScreen
    // instance; without the replay, a route sheet from before the remount
    // would claim a distance and duration over a blank map).
    _naviMap = MapboxNaviMapController(
      map: mapboxMap,
      routes: routes,
      markers: markers,
      arrowMarkers: arrowMarkers,
      footprints: footprints,
    );
    if (_is3d) await _naviMap!.setPitch(65);
    await _flow.attachMap(_naviMap!);
    await _applyRaisedBuildings();

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
        enabled: _flow.state is! FlowActiveNavigation,
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
      unawaited(_passLivePosition(_position!));
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
            unawaited(_passLivePosition(position));
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
        pitch: _is3d ? 65 : 0,
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
        pitch: _is3d ? 65 : 0,
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
        final locationMessage =
            state is FlowActiveNavigation && state.routeNotice != null
            ? state.routeNotice
            : flow.locationNotice ?? _locationMessage;
        return PopScope(
          canPop: state is FlowIdle,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) flow.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.map,
            bottomNavigationBar:
                state is FlowActiveNavigation || state is FlowArrived
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
                if (state is FlowArrived) _arrivalSummary(state, flow, padding),
                if (state is FlowError) _error(state, flow),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mapWidget() {
    // MapWidget treats each new ViewportState as a camera command. This must
    // stay the same object after the map is created; rebuilding it on flow
    // updates was snapping the camera back to campus top-down and undoing
    // both route previews and the 3D pitch.
    _initialMapViewport ??= CameraViewportState(
      center: Point(coordinates: Position(csulbLng, csulbLat)),
      zoom: csulbZoom,
    );
    return MapWidget(
      key: const ValueKey('navipet-map'),
      styleUri: _mapStyle,
      viewport: _initialMapViewport,
      onMapCreated: _onMapCreated,
    );
  }

  Widget _mapTypeControls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _mapControlButton(
        icon: Icons.layers_outlined,
        label: 'Map type',
        onPressed: _showMapTypePicker,
      ),
      const SizedBox(height: AppSpacing.sm),
      _mapControlButton(
        icon: _is3d ? Icons.map : Icons.threed_rotation,
        label: _is3d ? 'Switch to 2D map view' : 'Switch to 3D map view',
        selected: _is3d,
        onPressed: _toggle3d,
      ),
    ],
  );

  Future<void> _toggle3d() async {
    final next = !_is3d;
    setState(() {
      _is3d = next;
      _remembered3d = next;
    });
    await _naviMap?.setPitch(next ? 65 : 0);
  }

  Widget _mapControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool selected = false,
  }) => Material(
    color: selected ? AppColors.navy : Colors.white,
    elevation: 3,
    shape: const CircleBorder(),
    child: Semantics(
      label: label,
      button: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, color: selected ? Colors.white : AppColors.navy),
      ),
    ),
  );

  Future<void> _showMapTypePicker() async {
    final style = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const ListTile(
                  title: Text(
                    'Map type',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _mapStyleOption('Standard', mapboxStyle),
                _mapStyleOption('Satellite', mapboxSatelliteStyle),
                _mapStyleOption('Terrain', mapboxTerrainStyle),
                const Divider(height: AppSpacing.md),
                const ListTile(
                  title: Text(
                    'Map details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.apartment_outlined),
                  title: const Text('Raised buildings'),
                  subtitle: const Text('Show 3D buildings and landmarks'),
                  value: _raisedBuildings,
                  onChanged: (value) async {
                    setState(() {
                      _raisedBuildings = value;
                      _rememberedRaisedBuildings = value;
                    });
                    setSheetState(() {});
                    await _applyRaisedBuildings();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.directions_bike_outlined),
                  title: const Text('Bicycling'),
                  subtitle: const Text('Show bicycle-friendly map details'),
                  value: _bicycling,
                  onChanged: (value) async {
                    setState(() => _bicycling = value);
                    setSheetState(() {});
                    if (value) {
                      _styleBeforeBicycling = _mapStyle;
                    } else if (_styleBeforeBicycling != null) {
                      _mapStyle = _styleBeforeBicycling!;
                      _styleBeforeBicycling = null;
                    }
                    final style = value ? mapboxTerrainStyle : _mapStyle;
                    await _map?.loadStyleURI(style);
                    await _applyRaisedBuildings();
                    if (_naviMap != null) {
                      await _flow.attachMap(_naviMap!);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || style == null || (style == _mapStyle && !_bicycling)) {
      return;
    }
    setState(() => _bicycling = false);
    setState(() => _mapStyle = style);
    _styleBeforeBicycling = null;
    await _map?.loadStyleURI(style);
    await _applyRaisedBuildings();
    if (_naviMap != null) await _flow.attachMap(_naviMap!);
  }

  Future<void> _applyRaisedBuildings() async {
    final map = _map;
    if (map == null || _mapStyle != mapboxStyle || _bicycling) return;
    if (!await map.style.isStyleLoaded()) return;
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'show3dObjects',
      _raisedBuildings,
    );
  }

  Widget _mapStyleOption(String title, String style) => ListTile(
    leading: Icon(
      style == mapboxSatelliteStyle
          ? Icons.satellite_alt_outlined
          : style == mapboxTerrainStyle
          ? Icons.terrain_outlined
          : Icons.map_outlined,
    ),
    title: Text(title),
    trailing: style == _mapStyle
        ? const Icon(Icons.check, color: AppColors.navy)
        : null,
    onTap: () => Navigator.of(context).pop(style),
  );

  Widget _searchBar(BuildContext context, EdgeInsets padding) {
    return Positioned(
      top: padding.top + AppSpacing.sm,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: SearchBarField(
        placeholder: 'Where to?',
        onPressed: _flow.openSearch,
        right: const AccountButton(),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapTypeControls(),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
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
        ],
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
                        if (state is FlowApproaching)
                          const Text(
                            'Arriving soon',
                            style: TextStyle(
                              color: AppColors.amberInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          '${_remainingDurationLabel(state)} · ${_remainingLabel(state)}',
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

  String _remainingLabel(FlowActiveNavigation state) {
    final meters = state.remainingMeters ?? state.plan.selected.distanceMeters;
    if (meters < 160.9344) return '${(meters * 3.28084).round()} ft remaining';
    return '${(meters / 1609.344).toStringAsFixed(1)} mi remaining';
  }

  String _remainingDurationLabel(FlowActiveNavigation state) {
    final route = state.plan.selected;
    final fraction = route.distanceMeters <= 0
        ? 1.0
        : ((state.remainingMeters ?? route.distanceMeters) /
                  route.distanceMeters)
              .clamp(0.0, 1.0);
    final minutes = (route.durationSeconds * fraction / 60).ceil();
    return '$minutes min';
  }

  Widget _arrivalSummary(
    FlowArrived state,
    NavigationFlowController flow,
    EdgeInsets padding,
  ) => Positioned(
    left: AppSpacing.lg,
    right: AppSpacing.lg,
    bottom: padding.bottom + AppSpacing.lg,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You’ve arrived!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(state.destination.name),
            const SizedBox(height: 16),
            Text('Time: ${state.summary.elapsedLabel}'),
            Text('Distance traveled: ${state.summary.distanceLabel}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: flow.dismissArrival,
              child: const Text('Return to map'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmEnd(NavigationFlowController flow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this route?'),
        content: const Text('Guidance stops and the route is cleared.'),
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
}
