import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_state.dart';
import '../data/mapbox_config.dart';
import '../data/mapbox_navigation_service.dart';
import '../data/navigation_models.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/search_bar_field.dart';

const _mapStyleOptions = <_MapStyleOption>[
  _MapStyleOption('Standard', MapboxStyles.STANDARD, Icons.map_outlined),
  _MapStyleOption('Satellite', MapboxStyles.SATELLITE, Icons.satellite_alt),
  _MapStyleOption('Satellite streets', MapboxStyles.SATELLITE_STREETS, Icons.layers),
  _MapStyleOption('Outdoors', MapboxStyles.OUTDOORS, Icons.terrain),
  _MapStyleOption('Dark', MapboxStyles.DARK, Icons.dark_mode_outlined),
];

class _MapStyleOption {
  const _MapStyleOption(this.label, this.uri, this.icon);
  final String label;
  final String uri;
  final IconData icon;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _lastLatitudeKey = 'last_location_latitude';
  static const _lastLongitudeKey = 'last_location_longitude';

  late final MapboxNavigationService _navigationService;
  late final Future<void> _lastLocationReady;
  final FlutterTts _tts = FlutterTts();
  final Completer<void> _initialLocationReady = Completer<void>();

  MapboxMap? _map;
  PolylineAnnotationManager? _routeManager;
  PointAnnotationManager? _destinationManager;
  StreamSubscription<geo.Position>? _positionSubscription;
  StreamSubscription<StepCount>? _stepCountSubscription;
  geo.Position? _position;
  NavigationCoordinate? _lastKnownCoordinate;
  NaviDestination? _destination;
  NavigationRoute? _route;
  int _stepIndex = 0;
  bool _loadingRoute = false;
  bool _navigating = false;
  String? _locationMessage;
  DateTime? _lastReroute;
  DateTime? _tripStartedAt;
  int? _latestStepCount;
  int? _tripStepBaseline;
  bool _arrivalInProgress = false;
  int _routeRequestId = 0;
  String _mapStyle = mapboxStyle;
  bool _locationModeActive = false;
  bool _locationMode3d = false;

  @override
  void initState() {
    super.initState();
    _navigationService = MapboxNavigationService(
      accessToken: mapboxPublicToken,
    );
    _lastLocationReady = _loadLastKnownLocation();
    _tts
      ..setLanguage('en-US')
      ..setSpeechRate(0.48);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _tts.stop();
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
    _routeManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _destinationManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    await _lastLocationReady;
    await _centerOnBestKnownLocation();
    try {
      await _initializeLocation();
    } finally {
      if (!_initialLocationReady.isCompleted) {
        _initialLocationReady.complete();
      }
    }
  }

  Future<void> _loadLastKnownLocation() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_lastLatitudeKey);
    final longitude = preferences.getDouble(_lastLongitudeKey);
    if (latitude == null || longitude == null) return;
    _lastKnownCoordinate = NavigationCoordinate(
      latitude: latitude,
      longitude: longitude,
    );
    if (mounted) setState(() {});
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
        await _centerOnBestKnownLocation();
      }
      return;
    }
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() => _locationMessage = 'Turn on Location Services.');
        await _centerOnBestKnownLocation();
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
        await _centerOnUser();
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
            if (_locationMode3d && !_navigating) {
              unawaited(
                _setLocationCamera(
                  NavigationCoordinate(
                    latitude: position.latitude,
                    longitude: position.longitude,
                  ),
                  threeDimensional: true,
                ),
              );
            }
            if (_navigating) unawaited(_handleNavigationUpdate(position));
          },
          onError: (Object error) {
            if (mounted) setState(() => _locationMessage = error.toString());
          },
        );
  }

  Future<void> _openSearch() async {
    final destination = await context.push<NaviDestination>('/search');
    if (!mounted || destination == null) return;
    final wantsDirections = await _askForDirections(destination);
    if (!mounted || !wantsDirections) return;
    await _previewRoute(destination);
  }

  Future<bool> _askForDirections(NaviDestination destination) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        key: const ValueKey('directions-prompt'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: AppColors.amberInk,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get directions?',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (destination.address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          destination.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.screenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.my_location, size: 18, color: AppColors.navy),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Preview a walking route from your current location',
                      style: TextStyle(
                        color: AppColors.labelInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.inputBorder),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    key: const ValueKey('preview-directions-button'),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.route_rounded, size: 20),
                    label: const Text('Preview route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _previewRoute(NaviDestination destination) async {
    final requestId = ++_routeRequestId;
    setState(() {
      _destination = destination;
      _loadingRoute = true;
      _navigating = false;
      _route = null;
      _stepIndex = 0;
    });

    // Search can return before the map's initial GPS lookup has completed.
    // Give that lookup a short chance to finish so the first route request
    // starts from the user's position instead of the campus fallback. Location
    // errors and slow fixes still fall back without blocking navigation.
    try {
      await _initialLocationReady.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Continue with the last known or default coordinate below.
    }
    if (!mounted || requestId != _routeRequestId) return;

    final origin = _position == null
        ? (_lastKnownCoordinate ??
              const NavigationCoordinate(
                latitude: csulbLat,
                longitude: csulbLng,
              ))
        : NavigationCoordinate(
            latitude: _position!.latitude,
            longitude: _position!.longitude,
          );

    try {
      final route = await _navigationService.getRoute(
        origin: origin,
        destination: destination.coordinate,
      );
      if (!mounted || requestId != _routeRequestId) return;
      await _drawRoute(route, destination, origin: origin);
      if (!mounted || requestId != _routeRequestId) return;
      setState(() => _route = route);
    } catch (error) {
      if (mounted && requestId == _routeRequestId) {
        setState(() {
          _destination = null;
          _route = null;
        });
        _showMessage(error.toString());
      }
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  Future<void> _drawRoute(
    NavigationRoute route,
    NaviDestination destination, {
    NavigationCoordinate? origin,
  }) async {
    await _routeManager?.deleteAll();
    await _destinationManager?.deleteAll();
    if (route.coordinates.isNotEmpty) {
      await _routeManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: route.coordinates
                .map((point) => Position(point.longitude, point.latitude))
                .toList(),
          ),
          lineColor: AppColors.navy.toARGB32(),
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 2,
          lineWidth: 7,
          lineJoin: LineJoin.ROUND,
        ),
      );
    }
    await _destinationManager?.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            destination.coordinate.longitude,
            destination.coordinate.latitude,
          ),
        ),
        textField: destination.name,
        textOffset: [0, -1.8],
        textColor: AppColors.navy.toARGB32(),
        textHaloColor: Colors.white.toARGB32(),
        textHaloWidth: 2,
        textSize: 13,
      ),
    );
    await _fitRoute(route, destination, origin: origin);
  }

  Future<void> _fitRoute(
    NavigationRoute route,
    NaviDestination destination, {
    NavigationCoordinate? origin,
  }) async {
    final map = _map;
    if (map == null) return;
    final coordinates = [
      if (origin != null) origin,
      ...route.coordinates,
      // Always include the selected destination, even when route geometry is
      // sparse, so preview frames the place the user actually selected.
      destination.coordinate,
    ];
    if (coordinates.isEmpty) return;
    final camera = await map.cameraForCoordinatesPadding(
      coordinates
          .map(
            (point) =>
                Point(coordinates: Position(point.longitude, point.latitude)),
          )
          .toList(),
      CameraOptions(bearing: 0, pitch: 0),
      MbxEdgeInsets(top: 150, left: 50, bottom: 300, right: 50),
      17,
      null,
    );
    await map.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  Future<void> _startNavigation() async {
    final route = _route;
    if (route == null || route.steps.isEmpty) return;
    if (_position == null) {
      _showMessage('Waiting for your GPS location before navigation starts.');
      return;
    }
    setState(() {
      _navigating = true;
      _stepIndex = 0;
      _tripStartedAt = DateTime.now();
      _tripStepBaseline = _latestStepCount;
    });
    await _startStepTracking();
    await _speak(route.steps.first.instruction);
    await _centerOnUser(following: true);
  }

  Future<void> _handleNavigationUpdate(geo.Position position) async {
    final route = _route;
    final destination = _destination;
    if (!_navigating ||
        _arrivalInProgress ||
        route == null ||
        destination == null) {
      return;
    }

    if (_stepIndex < route.steps.length) {
      final step = route.steps[_stepIndex];
      final distance = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        step.maneuver.latitude,
        step.maneuver.longitude,
      );
      if (distance < 18 && _stepIndex < route.steps.length - 1) {
        setState(() => _stepIndex += 1);
        await _speak(route.steps[_stepIndex].instruction);
      }
    }

    final arrivalDistance = geo.Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.coordinate.latitude,
      destination.coordinate.longitude,
    );
    if (arrivalDistance < 15) {
      await _completeArrival(destination);
      return;
    }

    await _maybeReroute(position, route, destination);
    await _centerOnUser(following: true);
  }

  Future<void> _maybeReroute(
    geo.Position position,
    NavigationRoute route,
    NaviDestination destination,
  ) async {
    if (route.coordinates.isEmpty) return;
    var nearestDistance = double.infinity;
    for (var index = 0; index < route.coordinates.length; index += 4) {
      final point = route.coordinates[index];
      final distance = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearestDistance) nearestDistance = distance;
    }
    if (nearestDistance < 45) return;
    if (_lastReroute != null &&
        DateTime.now().difference(_lastReroute!) <
            const Duration(seconds: 15)) {
      return;
    }

    _lastReroute = DateTime.now();
    try {
      final newRoute = await _navigationService.getRoute(
        origin: NavigationCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        destination: destination.coordinate,
      );
      await _drawRoute(
        newRoute,
        destination,
        origin: NavigationCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      if (!mounted) return;
      setState(() {
        _route = newRoute;
        _stepIndex = 0;
      });
      if (newRoute.steps.isNotEmpty) {
        await _speak('Route updated. ${newRoute.steps.first.instruction}');
      }
    } catch (_) {
      // Keep the last valid route if a background reroute cannot be fetched.
    }
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

  Future<void> _onLocationControlPressed() async {
    final coordinate = _position == null
        ? _lastKnownCoordinate
        : NavigationCoordinate(
            latitude: _position!.latitude,
            longitude: _position!.longitude,
          );
    if (coordinate == null) {
      _showMessage('Waiting for a GPS location.');
      return;
    }

    final camera = await _map?.getCameraState();
    final cameraCenter = camera?.center.coordinates;
    final isAlreadyAtLocation = cameraCenter is Position &&
        geo.Geolocator.distanceBetween(
              coordinate.latitude,
              coordinate.longitude,
              cameraCenter.lat.toDouble(),
              cameraCenter.lng.toDouble(),
            ) <
            80;

    if (!_locationModeActive || !isAlreadyAtLocation) {
      _locationModeActive = true;
      _locationMode3d = false;
      await _setLocationCamera(coordinate, threeDimensional: false);
      if (mounted) setState(() {});
      return;
    }

    _locationMode3d = !_locationMode3d;
    await _setLocationCamera(coordinate, threeDimensional: _locationMode3d);
    if (mounted) setState(() {});
  }

  Future<void> _setLocationCamera(
    NavigationCoordinate coordinate, {
    required bool threeDimensional,
  }) async {
    final heading = _position?.heading;
    await _map?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(coordinate.longitude, coordinate.latitude),
        ),
        zoom: threeDimensional ? 17.5 : 16,
        pitch: threeDimensional ? 55 : 0,
        bearing: threeDimensional && heading != null && heading >= 0
            ? heading
            : 0,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  Future<void> _showMapStyles() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Map details'),
              subtitle: Text('Choose how the map is displayed'),
            ),
            for (final style in _mapStyleOptions)
              RadioListTile<String>(
                value: style.uri,
                groupValue: _mapStyle,
                title: Text(style.label),
                secondary: Icon(style.icon),
                onChanged: (value) => Navigator.of(sheetContext).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == _mapStyle) return;
    final camera = await _map?.getCameraState();
    setState(() => _mapStyle = selected);
    await _map?.loadStyleURI(selected);
    if (!mounted) return;
    if (_route != null && _destination != null) {
      await _drawRoute(_route!, _destination!);
    } else if (camera != null) {
      await _map?.easeTo(
        CameraOptions(
          center: camera.center,
          zoom: camera.zoom,
          bearing: camera.bearing,
          pitch: camera.pitch,
        ),
        MapAnimationOptions(duration: 0),
      );
    }
  }

  Future<void> _startStepTracking() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return;
    }
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (event) {
        _latestStepCount = event.steps;
        _tripStepBaseline ??= event.steps;
      },
      onError: (_) {
        _latestStepCount = null;
        _tripStepBaseline = null;
      },
    );
  }

  Future<void> _completeArrival(NaviDestination destination) async {
    _arrivalInProgress = true;
    final startedAt = _tripStartedAt;
    final baseline = _tripStepBaseline;
    final currentSteps = _latestStepCount;
    final countedSteps = baseline == null || currentSteps == null
        ? null
        : (currentSteps - baseline).clamp(0, 1 << 31).toInt();
    final summary = NavigationTripSummary(
      elapsed: startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt),
      walkingSteps: countedSteps,
    );

    await _removeRoute();
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    await _speak('You have arrived at ${destination.name}.');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.green, size: 56),
        title: const Text('You have arrived!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _summaryRow(
              Icons.timer_outlined,
              'Travel time',
              summary.elapsedLabel,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              Icons.directions_walk,
              'Walking steps',
              summary.walkingStepsLabel,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    _arrivalInProgress = false;
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.navy),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Future<void> _stopNavigation() async {
    await _clearRoute();
  }

  Future<void> _clearRoute() async {
    _routeRequestId++;
    await _tts.stop();
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    await _removeRoute();
  }

  Future<void> _removeRoute() async {
    await _routeManager?.deleteAll();
    await _destinationManager?.deleteAll();
    if (mounted) {
      setState(() {
        _destination = null;
        _route = null;
        _navigating = false;
        _stepIndex = 0;
        _tripStartedAt = null;
        _tripStepBaseline = null;
      });
    }
  }

  Future<void> _speak(String instruction) async {
    await _tts.stop();
    await _tts.speak(instruction);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = context.watch<AppState>().activeUser;
    final padding = MediaQuery.paddingOf(context);

    final initialCoordinate =
        _lastKnownCoordinate ??
        const NavigationCoordinate(latitude: csulbLat, longitude: csulbLng);

    return Scaffold(
      backgroundColor: AppColors.map,
      bottomNavigationBar: _navigating
          ? null
          : const NaviBottomNav(active: NaviTab.location),
      body: Stack(
        children: [
          MapWidget(
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
          ),
          if (!_navigating)
            Positioned(
              top: padding.top + AppSpacing.sm,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: SearchBarField(
                placeholder: _destination?.name ?? 'Where to?',
                onPressed: _openSearch,
                right: GestureDetector(
                  onTap: () => context.push('/account'),
                  child: _avatar(
                    activeUser?.name ?? '?',
                    activeUser?.avatarColor ?? AppColors.amber,
                  ),
                ),
              ),
            ),
          if (_navigating && _route != null)
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: _instructionCard(_route!),
            ),
          Positioned(
            right: 16,
            bottom: _route == null
                ? 24
                : (_navigating ? 142 + padding.bottom : 294),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapControl(
                  heroTag: 'map-style',
                  tooltip: 'Map details and type',
                  icon: Icons.layers_outlined,
                  onPressed: _showMapStyles,
                ),
                const SizedBox(height: 12),
                _mapControl(
                  heroTag: 'recenter',
                  tooltip: _locationMode3d
                      ? 'Switch to 2D location view'
                      : _locationModeActive
                      ? 'Switch to 3D heading view'
                      : 'Center on my location',
                  icon: _locationMode3d
                      ? Icons.threed_rotation
                      : Icons.my_location,
                  onPressed: _onLocationControlPressed,
                ),
              ],
            ),
          ),
          if (_locationMessage != null)
            Positioned(
              left: 16,
              right: 16,
              top: padding.top + (_navigating ? 112 : 80),
              child: Material(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_locationMessage!),
                ),
              ),
            ),
          if (_loadingRoute)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x3D002B5B),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppShadows.card,
                    ),
                    child: const Row(
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
                        SizedBox(width: 14),
                        Text(
                          'Finding the best walking route…',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_route != null && _destination != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _navigating ? padding.bottom + 12 : 12,
              child: _routeCard(_route!, _destination!),
            ),
        ],
      ),
    );
  }

  Widget _instructionCard(NavigationRoute route) {
    final step = route.steps.isEmpty
        ? null
        : route.steps[_stepIndex.clamp(0, route.steps.length - 1)];
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
          ],
        ),
      ),
    );
  }

  Widget _mapControl({
    required String heroTag,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      tooltip: tooltip,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 5,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  Widget _routeCard(NavigationRoute route, NaviDestination destination) {
    if (_navigating) {
      return Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.accentSoft,
                child: Icon(Icons.directions_walk, color: AppColors.amberInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${route.durationLabel} • ${route.distanceLabel}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _stopNavigation,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End'),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'ROUTE PREVIEW',
                    style: TextStyle(
                      color: AppColors.amberInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _clearRoute,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close route preview',
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              destination.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (destination.address.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                destination.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _routeStat(
                    Icons.schedule_rounded,
                    route.durationLabel,
                    'Estimated',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _routeStat(
                    Icons.straighten_rounded,
                    route.distanceLabel,
                    'Distance',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _routeStat(
                    Icons.directions_walk_rounded,
                    'Walking',
                    'Route type',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              key: const ValueKey('confirm-navigation-button'),
              onPressed: _startNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.navigation_rounded),
              label: const Text(
                'Confirm navigation',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.screenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.navy),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 9),
          ),
        ],
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
