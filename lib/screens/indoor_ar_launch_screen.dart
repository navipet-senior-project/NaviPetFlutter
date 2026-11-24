import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/campus_search_gateway.dart';
import '../data/campus_place.dart';
import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';
import '../data/indoor_ar_token_gateway.dart';
import '../data/indoor_floor_coverage.dart';
import '../data/start_floor_anchor.dart';

/// Asks for the camera, opens the Unity AR camera and returns to the map.
/// Opened fresh by every AR tap, so every tap asks again.
class IndoorArLaunchScreen extends StatefulWidget {
  const IndoorArLaunchScreen({
    super.key,
    required this.launcher,
    required this.destinationId,
    required this.gateway,
    required this.tokenGateway,
    this.request,
    this.anchor,
    this.now = DateTime.now,
    this.cameraStatus = _cameraStatus,
    this.requestCamera = _requestCamera,
    this.openSettings = openAppSettings,
  });

  final IndoorArLauncher launcher;
  final String? destinationId;
  final IndoorArRequest? request;
  final CampusSearchGateway gateway;

  /// Null skips the "which floor are you on" question. Owned by this screen,
  /// which starts and disposes it.
  final StartFloorAnchor? anchor;

  /// Null when the app has no backend session to ask; AR is then unavailable.
  final IndoorArTokenGateway? tokenGateway;
  final DateTime Function() now;
  final Future<PermissionStatus> Function() cameraStatus;
  final Future<PermissionStatus> Function() requestCamera;
  final Future<bool> Function() openSettings;

  static Future<PermissionStatus> _cameraStatus() => Permission.camera.status;

  static Future<PermissionStatus> _requestCamera() =>
      Permission.camera.request();

  @override
  State<IndoorArLaunchScreen> createState() => _IndoorArLaunchScreenState();
}

class _IndoorArLaunchScreenState extends State<IndoorArLaunchScreen> {
  /// A token this close to expiry could lapse before Unity localises.
  static const _tokenMargin = Duration(minutes: 1);
  static const _cameraOff =
      'Camera access is off. Turn it on in Settings to use AR directions.';
  static const _errorText = {
    'ARCORE_UNSUPPORTED': "This phone doesn't support AR.",
    'UNITY_EXITED': 'AR closed unexpectedly.',
    'BAD_REQUEST': "AR couldn't start.",
    'BAD_RESULT': 'AR returned an unreadable result.',
  };

  IndoorArRequest? _request;
  var _guideToRoom = false;
  var _unavailable = false;
  var _tokenFailed = false;
  String? _placeLookupFailure;
  var _rationale = false;
  var _blocked = false;
  var _choosingFloor = false;
  var _floorAsked = false;
  var _holding = false;
  String? _retryText;
  StartFloorAnchor? _anchor;

  @override
  void initState() {
    super.initState();
    // Kept from the first build: a router rebuild hands the widget a fresh
    // anchor. It reads no sensor until the user confirms a floor.
    _anchor = widget.anchor;
    // After the first frame: leaving pops the route, which initState cannot do.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    // A retry asks again: an old answer is never reused, and nothing is read
    // until the user confirms a floor once more.
    _floorAsked = false;
    await _anchor?.reset();
    if (!mounted) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _leave("AR mode isn't available on this device.");
      return;
    }
    setState(() {
      _unavailable = false;
      _tokenFailed = false;
      _placeLookupFailure = null;
      _retryText = null;
    });
    final request = widget.request;
    final id = widget.destinationId?.trim();
    if (request != null) {
      if (request.mapCode != IndoorArRequest.buildMapCode ||
          request.frame != IndoorArRequest.buildFrame ||
          !indoorScanCovered('VEC', request.floor)) {
        setState(() => _unavailable = true);
        return;
      }
      _request = request;
      _guideToRoom = !request.isLocalize;
    } else if (id == null || id.isEmpty) {
      setState(() => _unavailable = true);
      return;
    } else {
      try {
        final place = await widget.gateway.place(id);
        if (!mounted) return;
        final indoor = place.indoor;
        if (!indoorScanCovered(place.buildingCode, place.floorNumber)) {
          setState(() => _unavailable = true);
          return;
        }
        if (indoor == null) {
          _request = IndoorArRequest.localize(
            room: place.roomNumber ?? place.title,
            floor: place.floorNumber ?? '',
            mapCode: IndoorArRequest.buildMapCode,
            frame: IndoorArRequest.buildFrame,
          );
          _guideToRoom = false;
        } else {
          _request = IndoorArRequest(
            room: place.roomNumber ?? place.title,
            doorKey: indoor.doorKey,
            floor: indoor.floor,
            position: indoor.position,
            headingDeg: indoor.headingDeg,
            mapCode: indoor.mapCode,
            frame: indoor.frame,
          );
          _guideToRoom = true;
        }
      } on CampusSearchException catch (error) {
        if (mounted) {
          setState(() {
            _placeLookupFailure = switch (error.failure) {
              CampusSearchFailure.offline =>
                'Could not load this place. Check your connection and try again.',
              CampusSearchFailure.unauthorized =>
                'Could not verify your account. Sign in again and retry.',
              CampusSearchFailure.api =>
                'Could not load place details. Try again.',
            };
          });
        }
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _placeLookupFailure = 'Could not load place details. Try again.';
          });
        }
        return;
      }
    }
    if (_anchor != null && !_floorAsked) {
      setState(() => _choosingFloor = true);
      return;
    }
    await _checkCamera();
  }

  /// [floor] is what the user said they stand on; null means they skipped.
  Future<void> _floorChosen(String? floor) async {
    _floorAsked = true;
    setState(() => _choosingFloor = false);
    if (floor == null || !_anchor!.confirmFloor(floor)) {
      await _checkCamera();
      return;
    }
    // The barometer needs a still phone for about 20 s after the answer.
    setState(() => _holding = true);
    while (mounted && _holding && !_anchor!.resolved) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted && _holding) await _stopHolding();
  }

  Future<void> _stopHolding() async {
    setState(() => _holding = false);
    await _checkCamera();
  }

  Future<void> _checkCamera() async {
    try {
      final camera = await widget.cameraStatus();
      if (!mounted) return;
      if (camera.isGranted) {
        await _launch();
      } else {
        setState(() => _rationale = true);
      }
    } catch (error) {
      _launchFailed(error);
    }
  }

  Future<void> _askForCamera() async {
    setState(() => _rationale = false);
    try {
      final camera = await widget.requestCamera();
      if (!mounted) return;
      if (camera.isPermanentlyDenied) {
        setState(() => _blocked = true);
      } else if (camera.isGranted) {
        await _launch();
      } else {
        _leave(_cameraOff);
      }
    } catch (error) {
      _launchFailed(error);
    }
  }

  Future<void> _launch() async {
    // Minted now, after the camera step, so it is as fresh as possible and a
    // refused permission never spends one of the 5-per-minute requests.
    final IndoorArToken token;
    try {
      final gateway = widget.tokenGateway;
      if (gateway == null) throw const IndoorArTokenException(0);
      token = await gateway.fetch();
      if (!token.expiresOn.isAfter(widget.now().add(_tokenMargin))) {
        throw const IndoorArTokenException(0);
      }
    } on IndoorArTokenException {
      _anchor?.reset(); // the failure screen collects nothing
      if (mounted) {
        setState(() {
          _unavailable = true;
          _tokenFailed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    final evidence = _anchor?.evidence();
    final result = await widget.launcher.launch(
      _request!.withArToken(token).withStartFloor(evidence),
    );
    if (!mounted) return;
    // The evidence is spent: Unity has stopped sampling and never reuses it.
    _anchor?.reset();
    if (evidence != null &&
        result.status == IndoorArStatus.localizationFailed) {
      // Unity's "Try again" returns here (Addendum 9): ask the floor afresh.
      setState(() => _retryText = _resultText(result));
      return;
    }
    _leave(_resultText(result));
  }

  void _launchFailed(Object error) {
    debugPrint('[IndoorAr] launch failed: $error');
    _leave(_errorText['UNITY_EXITED']);
  }

  String? _resultText(IndoorArResult result) => switch (result.status) {
    IndoorArStatus.arrived when _guideToRoom && _signConfirmed(result) =>
      'Found the ${_request!.room} sign. You have arrived.',
    IndoorArStatus.arrived when _guideToRoom && result.checkDistanceM == null =>
      _errorText[IndoorArResult.badResultCode],
    IndoorArStatus.arrived =>
      !_guideToRoom
          ? 'MultiSet localized this area.'
          : 'MultiSet localized this area. Room ${_request!.room} is ${result.checkDistanceM!.toStringAsFixed(1)} m away${result.confidence == null ? '' : ' (confidence ${(result.confidence! * 100).round()}%)'}.',
    IndoorArStatus.localizationFailed =>
      'Could not match this camera view to the VEC map. Try facing a well lit wall, door, or sign.',
    IndoorArStatus.cancelled => null,
    IndoorArStatus.unavailable => 'AR is not included in this build.',
    IndoorArStatus.error =>
      _errorText[result.errorCode] ?? 'AR failed (${result.errorCode}).',
  };

  /// The sign the runtime read is the destination's own, so the arrival holds
  /// with no distance. Any distance it carries is not shown.
  bool _signConfirmed(IndoorArResult result) =>
      _roomKey(result.signRoom ?? '') == _roomKey(_request!.doorKey);

  static String _roomKey(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  void _leave(String? message) {
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    context.canPop() ? context.pop() : context.go('/map');
  }

  Future<void> _openSettings() async {
    await widget.openSettings();
    // Back on the map, the next AR tap reads the new setting.
    _leave(null);
  }

  @override
  void dispose() {
    _anchor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:
        _blocked ||
            _rationale ||
            _unavailable ||
            _choosingFloor ||
            _holding ||
            _retryText != null ||
            _placeLookupFailure != null
        ? AppBar(title: const Text('AR mode'))
        : null,
    body: Center(
      child: _placeLookupFailure != null
          ? _message(
              _placeLookupFailure!,
              action: 'Retry',
              onAction: _start,
              back: 'Back to map',
              onBack: () => _leave(null),
            )
          : _retryText != null
          ? _message(
              _retryText!,
              action: 'Try again',
              onAction: _start,
              back: 'Back to map',
              onBack: () => _leave(null),
            )
          : _unavailable
          ? _message(
              _tokenFailed
                  ? "Couldn't start AR. Check your connection and try again."
                  : "Indoor AR isn't available for this room",
              action: 'Retry',
              onAction: _start,
              back: 'Back to map',
              onBack: () => _leave(null),
            )
          : _holding
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hold still for a few seconds while NaviPet checks your '
                    'floor with the barometer.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  TextButton(
                    onPressed: _stopHolding,
                    child: const Text('Continue without waiting'),
                  ),
                ],
              ),
            )
          : _choosingFloor
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Which floor are you standing on? Choosing one turns on the '
                    "barometer to check you don't change floors. Skip to "
                    'continue without it.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  for (final floor in scannedIndoorFloors.toList()..sort())
                    FilledButton(
                      onPressed: () => _floorChosen(floor),
                      child: Text('Floor $floor'),
                    ),
                  TextButton(
                    onPressed: () => _floorChosen(null),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            )
          : _blocked
          ? _message(
              _cameraOff,
              action: 'Open settings',
              onAction: _openSettings,
              back: 'Back to map',
              onBack: () => _leave(null),
            )
          : _rationale
          ? _message(
              _guideToRoom
                  ? 'Allow camera access so NaviPet can point toward this room. '
                        'This is a direction to the room, not turn-by-turn guidance.'
                  : 'Allow camera access to scan and find your position. '
                        'No door position is saved, so this does not start a route.',
              action: 'Continue',
              onAction: _askForCamera,
              back: 'Not now',
              onBack: () => _leave(
                'AR needs camera access. Tap the AR button to try again.',
              ),
            )
          : const CircularProgressIndicator(),
    ),
  );

  Widget _message(
    String text, {
    required String action,
    required VoidCallback onAction,
    required String back,
    required VoidCallback onBack,
  }) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onAction, child: Text(action)),
        TextButton(onPressed: onBack, child: Text(back)),
      ],
    ),
  );
}
