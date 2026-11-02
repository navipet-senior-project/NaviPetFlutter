import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/campus_search_gateway.dart';
import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';
import '../data/indoor_ar_token_gateway.dart';

/// Asks for the camera, opens the Unity AR camera and returns to the map.
/// Opened fresh by every AR tap, so every tap asks again.
class IndoorArLaunchScreen extends StatefulWidget {
  const IndoorArLaunchScreen({
    super.key,
    required this.launcher,
    required this.destinationId,
    required this.gateway,
    required this.tokenGateway,
    this.now = DateTime.now,
    this.cameraStatus = _cameraStatus,
    this.requestCamera = _requestCamera,
    this.openSettings = openAppSettings,
  });

  final IndoorArLauncher launcher;
  final String? destinationId;
  final CampusSearchGateway gateway;

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
  var _unavailable = false;
  var _rationale = false;
  var _blocked = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: leaving pops the route, which initState cannot do.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _leave("AR mode isn't available on this device.");
      return;
    }
    setState(() => _unavailable = false);
    try {
      final id = widget.destinationId;
      if (id == null || id.trim().isEmpty) {
        setState(() => _unavailable = true);
        return;
      }
      final place = await widget.gateway.place(id);
      if (!mounted) return;
      final indoor = place.indoor;
      if (indoor == null) {
        setState(() => _unavailable = true);
        return;
      }
      _request = IndoorArRequest(
        room: place.roomNumber ?? place.title,
        doorKey: indoor.doorKey,
        floor: indoor.floor,
        position: indoor.position,
        headingDeg: indoor.headingDeg,
        mapCode: indoor.mapCode,
        frame: indoor.frame,
      );
    } catch (_) {
      if (mounted) setState(() => _unavailable = true);
      return;
    }
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
      if (mounted) setState(() => _unavailable = true);
      return;
    }
    if (!mounted) return;
    final result = await widget.launcher.launch(_request!.withArToken(token));
    if (!mounted) return;
    _leave(_resultText(result));
  }

  void _launchFailed(Object error) {
    debugPrint('[IndoorAr] launch failed: $error');
    _leave(_errorText['UNITY_EXITED']);
  }

  String? _resultText(IndoorArResult result) => switch (result.status) {
    IndoorArStatus.arrived ||
    IndoorArStatus.localizationFailed ||
    IndoorArStatus.cancelled => null,
    IndoorArStatus.unavailable => 'AR is not included in this build.',
    IndoorArStatus.error =>
      _errorText[result.errorCode] ?? 'AR failed (${result.errorCode}).',
  };

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
  Widget build(BuildContext context) => Scaffold(
    appBar: _blocked || _rationale || _unavailable
        ? AppBar(title: const Text('AR mode'))
        : null,
    body: Center(
      child: _unavailable
          ? _message(
              "Indoor AR isn't available for this room",
              action: 'Retry',
              onAction: _start,
              back: 'Back to map',
              onBack: () => _leave(null),
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
              'Allow camera access so NaviPet can show arrows over the floor '
              'around you.',
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
