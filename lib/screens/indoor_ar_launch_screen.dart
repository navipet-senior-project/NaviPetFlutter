import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/campus_place.dart';
import '../data/campus_search_gateway.dart';
import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';
import '../data/navigation_flow_controller.dart';

enum _Phase {
  loading,
  loadFailed,
  unavailable,
  ready,
  running,
  cameraDenied,
  cameraBlocked,
}

/// Opens indoor AR for one room: loads its door pose, asks for the camera,
/// launches Unity and shows what came back.
class IndoorArLaunchScreen extends StatefulWidget {
  const IndoorArLaunchScreen({
    super.key,
    required this.destinationId,
    required this.launcher,
    this.gateway,
    this.requestCamera = _requestCamera,
  });

  final String destinationId;
  final IndoorArLauncher launcher;

  /// Null: the app's [NavigationFlowController.searchGateway].
  final CampusSearchGateway? gateway;
  final Future<PermissionStatus> Function() requestCamera;

  static Future<PermissionStatus> _requestCamera() =>
      Permission.camera.request();

  @override
  State<IndoorArLaunchScreen> createState() => _IndoorArLaunchScreenState();
}

class _IndoorArLaunchScreenState extends State<IndoorArLaunchScreen> {
  static const _errorText = {
    'ARCORE_UNSUPPORTED': "This phone doesn't support AR.",
    'MULTISET_AUTH': "Couldn't connect to the indoor map service.",
    'NETWORK': 'No internet connection. Check it and try again.',
    'UNITY_EXITED': 'AR closed unexpectedly.',
    'BAD_REQUEST': "This room's AR data is invalid.",
    'MAP_MISMATCH': "This room's AR data is for a different map.",
    'BAD_RESULT': 'AR returned an unreadable result.',
  };

  late final CampusSearchGateway _gateway =
      widget.gateway ?? context.read<NavigationFlowController>().searchGateway;
  var _phase = _Phase.loading;
  CampusPlace? _place;
  IndoorArResult? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.destinationId.isEmpty) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }
    setState(() => _phase = _Phase.loading);
    try {
      final place = await _gateway.place(widget.destinationId);
      if (!mounted) return;
      setState(() {
        _place = place;
        _phase = place.indoorRequest == null
            ? _Phase.unavailable
            : _Phase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.loadFailed);
    }
  }

  Future<void> _start() async {
    final request = _place!.indoorRequest!;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final camera = await widget.requestCamera();
      if (!mounted) return;
      if (!camera.isGranted) {
        setState(
          () => _phase = camera.isPermanentlyDenied
              ? _Phase.cameraBlocked
              : _Phase.cameraDenied,
        );
        return;
      }
    }
    setState(() => _phase = _Phase.running);
    try {
      final result = await widget.launcher.launch(request);
      debugPrint(
        '[IndoorAr] ${request.doorKey} ${result.status.name} '
        'distance=${result.checkDistanceM} confidence=${result.confidence} '
        'queries=${result.localizationQueries} durationMs=${result.durationMs} '
        'error=${result.errorCode}',
      );
      if (mounted) setState(() => _last = result);
    } finally {
      // A throwing launcher must not leave the button disabled.
      if (mounted) setState(() => _phase = _Phase.ready);
    }
  }

  String? _resultText(IndoorArResult result) => switch (result.status) {
    IndoorArStatus.arrived =>
      'Pin was ${result.checkDistanceM?.toStringAsFixed(1)} m from you',
    IndoorArStatus.localizationFailed => "Couldn't find your position",
    IndoorArStatus.cancelled => null,
    IndoorArStatus.unavailable => 'AR not included in this build',
    IndoorArStatus.error =>
      _errorText[result.errorCode] ?? 'AR failed (${result.errorCode})',
  };

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final last = _last;
    final resultText = last == null ? null : _resultText(last);
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor AR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (place != null)
            Text(place.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...switch (_phase) {
            _Phase.loading => [
              const Center(child: CircularProgressIndicator()),
            ],
            _Phase.loadFailed => [
              const Text("Couldn't load this room."),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
            _Phase.unavailable => [
              const Text("Indoor AR isn't available for this room"),
            ],
            _Phase.cameraDenied => [
              const Text('NaviPet needs the camera to show the door pin.'),
              FilledButton(onPressed: _start, child: const Text('Try again')),
            ],
            _Phase.cameraBlocked => [
              const Text('NaviPet needs the camera to show the door pin.'),
              FilledButton(
                onPressed: openAppSettings,
                child: const Text('Open settings'),
              ),
            ],
            _Phase.ready || _Phase.running => [
              if (resultText != null) Text(resultText),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _phase == _Phase.running ? null : _start,
                child: Text(
                  last?.status == IndoorArStatus.localizationFailed
                      ? 'Retry'
                      : 'Start AR',
                ),
              ),
            ],
          },
        ],
      ),
    );
  }
}
