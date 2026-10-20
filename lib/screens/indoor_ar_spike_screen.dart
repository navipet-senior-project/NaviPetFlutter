import 'package:flutter/material.dart';

import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';

/// Debug-only screen for the #41 transport spike: one request in, one result
/// out, repeatable. Replaced by the real launch screen in build step 3.
class IndoorArSpikeScreen extends StatefulWidget {
  const IndoorArSpikeScreen({super.key, required this.launcher});

  final IndoorArLauncher launcher;

  /// VEC 119 door as loaded into vec_destination_points (MapSet frame).
  static final vec119 = IndoorArRequest(
    room: '119',
    doorKey: 'VEC119',
    floor: '1',
    position: const IndoorArVector3(-5.7651, -1.8186, 22.6689),
    headingDeg: 185.36,
    mapCode: 'MSET_XTBY7AM7ZK77',
    frame: 'multiset-mapset',
  );

  @override
  State<IndoorArSpikeScreen> createState() => _IndoorArSpikeScreenState();
}

class _IndoorArSpikeScreenState extends State<IndoorArSpikeScreen> {
  var _launches = 0;
  var _running = false;
  IndoorArResult? _last;

  Future<void> _launch() async {
    setState(() => _running = true);
    final result = await widget.launcher.launch(IndoorArSpikeScreen.vec119);
    if (!mounted) return;
    debugPrint(
      '[IndoorAr] ${result.status.name} distance=${result.checkDistanceM} '
      'queries=${result.localizationQueries} durationMs=${result.durationMs} '
      'error=${result.errorCode}',
    );
    setState(() {
      _running = false;
      _launches++;
      _last = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = IndoorArSpikeScreen.vec119;
    final last = _last;
    final distance = last?.checkDistanceM;
    final errorCode = last?.errorCode;
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor AR spike')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Request: ${request.doorKey}, floor ${request.floor}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _running ? null : _launch,
            child: const Text('Launch AR'),
          ),
          const SizedBox(height: 16),
          Text('Launches: $_launches'),
          if (last != null) ...[
            Text('Status: ${last.status.name}'),
            if (distance != null)
              Text('Distance: ${distance.toStringAsFixed(2)} m'),
            if (errorCode != null) Text('Error: $errorCode'),
            Text(
              'Queries: ${last.localizationQueries}, '
              'duration: ${last.durationMs} ms',
            ),
          ],
        ],
      ),
    );
  }
}
