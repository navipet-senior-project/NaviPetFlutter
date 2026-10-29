import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/indoor_ar_contract.dart';
import '../data/indoor_ar_launcher.dart';

/// Debug-only VEC room picker for the door verifier device check: opens
/// `/ar?destinationId=` for one room without walking the outdoor route, and
/// shows a result that came back after Android restarted the app.
class IndoorArSpikeScreen extends StatefulWidget {
  const IndoorArSpikeScreen({super.key, required this.launcher});

  final IndoorArLauncher launcher;

  /// Active doors in vec_destination_points (floors 1–2), with their
  /// campus_destinations id, as of 2026-10-28.
  static const doors = <(String, String)>[
    ('VEC119', '3c011e42-ad7d-4f6c-81d5-e7b23e977d1f'),
    ('VEC120', '4be3965d-e8a9-44c7-b537-130030247b73'),
    ('VEC121', '9e0e4f69-489c-4878-9c6a-13088099439c'),
    ('VEC124', '0cbbd702-e0d9-4954-8041-b7b9adde130c'),
    ('VEC127', 'd217f392-7b76-4144-9561-847880aec2e8'),
    ('VEC128', '48946840-9bbc-4d43-b81e-1eb2d916e3c9'),
    ('VEC132', 'acae6c09-b287-4be4-b88d-f19bb1640c4b'),
    ('VEC134', '7d538d16-0216-4ca6-bdb2-60db49cb011c'),
    ('VEC136', '8bd597c1-4cf9-4805-9e0c-34db7dec69a9'),
    ('VEC201', '388d87e9-8d31-4e35-945d-14b32013e025'),
    ('VEC202', 'd1eea6ef-2abf-418b-a942-c32889649088'),
    ('VEC215', '630a1950-20e8-40a5-89a8-72ab00f131d2'),
    ('VEC217', 'da6fed01-a320-4613-987e-d972f318a65f'),
    ('VEC218', '3139ee48-32b3-4159-ad1e-61b91fe852db'),
    ('VEC220', '1f859c36-4962-4eb9-94cb-e0d6422fe5ba'),
    ('VEC224', 'e3ba922a-d968-4d61-833e-813913373c86'),
    ('VEC227', '9dd793bb-18fd-4321-bc75-fc68f11ea00e'),
  ];

  @override
  State<IndoorArSpikeScreen> createState() => _IndoorArSpikeScreenState();
}

class _IndoorArSpikeScreenState extends State<IndoorArSpikeScreen>
    with WidgetsBindingObserver {
  IndoorArResult? _recovered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _collect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Also on resume: the host may receive the result after Dart first asks.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _collect();
  }

  Future<void> _collect() async {
    final result = await widget.launcher.pendingResult();
    if (result == null || !mounted) return;
    debugPrint(
      '[IndoorAr] recovered ${result.status.name} '
      'distance=${result.checkDistanceM} confidence=${result.confidence} '
      'queries=${result.localizationQueries} durationMs=${result.durationMs} '
      'error=${result.errorCode}',
    );
    setState(() => _recovered = result);
  }

  @override
  Widget build(BuildContext context) {
    final recovered = _recovered;
    final distance = recovered?.checkDistanceM;
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor AR rooms')),
      body: ListView(
        children: [
          if (recovered != null)
            ListTile(
              title: Text(
                'Recovered result: ${recovered.status.name}'
                '${distance == null ? '' : ', ${distance.toStringAsFixed(2)} m'}'
                '${recovered.errorCode == null ? '' : ', ${recovered.errorCode}'}',
              ),
            ),
          for (final (doorKey, destinationId) in IndoorArSpikeScreen.doors)
            ListTile(
              title: Text(doorKey),
              onTap: () => context.push(
                '/ar?destinationId=${Uri.encodeQueryComponent(destinationId)}',
              ),
            ),
        ],
      ),
    );
  }
}
