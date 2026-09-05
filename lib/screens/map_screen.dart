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
    final startRoute = await context.push<bool>(
      '/place-details',
      extra: destination,
    );
    if (!mounted || startRoute != true) return;
    await _previewRoute(destination);
  }

  Future<void> _openDemoDestination() async {
    const destination = NaviDestination(
      name: 'College of Business',
      address: '1250 Bellflower Blvd, Long Beach, CA',
      coordinate: NavigationCoordinate(latitude: 33.7832, longitude: -118.1147),
    );
    final startRoute = await context.push<bool>(
      '/place-details',
      extra: destination,
    );
    if (!mounted || startRoute != true) return;
    await _previewRoute(destination);
  }

  Future<void> _previewRoute(NaviDestination destination) async {
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
    if (!mounted) return;

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
      await _drawRoute(route, destination);
      if (!mounted) return;
      setState(() => _route = route);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _drawRoute(
    NavigationRoute route,
    NaviDestination destination,
  ) async {
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
    await _fitRoute(route);
  }

  Future<void> _fitRoute(NavigationRoute route) async {
    final map = _map;
    if (map == null || route.coordinates.isEmpty) return;
    final camera = await map.cameraForCoordinatesPadding(
      route.coordinates
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
      await _drawRoute(newRoute, destination);
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
              pitch: 52,
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
          if (!_navigating && _route == null)
            Positioned(
              top: padding.top + 72,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _mapChip(Icons.apartment, 'Buildings'),
                  const SizedBox(width: 8),
                  _mapChip(Icons.restaurant, 'Food', selected: true),
                  const SizedBox(width: 8),
                  _mapChip(Icons.local_parking, 'Parking'),
                ],
              ),
            ),
          if (!_navigating && _route == null)
            Positioned(
              left: 24,
              bottom: 88,
              child: InkWell(
                onTap: _openDemoDestination,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.navy, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.card,
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.yellow,
                        child: Icon(Icons.pets, color: AppColors.navy),
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NAVIPET GUIDE',
                            style: TextStyle(
                              color: AppColors.faint,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Need directions?',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
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
            bottom:
                (_route == null ? 24 : 210) +
                (_navigating ? padding.bottom : 0),
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
              onPressed: _centerOnBestKnownLocation,
              child: const Icon(Icons.my_location),
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
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.turn_right,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step?.instruction ?? 'Follow the highlighted route',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step == null
                            ? route.distanceLabel
                            : _distanceText(step.distanceMeters),
                        style: const TextStyle(
                          color: AppColors.labelInk,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: -18,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppShadows.soft,
            ),
            child: const Icon(Icons.pets, color: AppColors.navy, size: 27),
          ),
        ),
      ],
    );
  }

  Widget _routeCard(NavigationRoute route, NaviDestination destination) {
    final arrivalTime = TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(seconds: route.durationSeconds.round())),
    ).format(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  route.durationLabel.replaceFirst(' min', ''),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(' min', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${route.distanceLabel}  •  ETA $arrivalTime',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_navigating)
                  IconButton(
                    onPressed: _clearRoute,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigating ? _stopNavigation : _startNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navigating
                      ? const Color(0xFFFFD9D9)
                      : AppColors.navy,
                  foregroundColor: _navigating
                      ? AppColors.danger
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
                icon: Icon(_navigating ? Icons.stop : Icons.navigation),
                label: Text(_navigating ? 'Exit' : 'Start Walking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceText(double meters) {
    if (meters < 160) return '${(meters * 3.28084).round()} ft';
    return '${(meters / 1609.344).toStringAsFixed(1)} mi';
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

  Widget _mapChip(IconData icon, String label, {bool selected = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.inputBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.navy),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
