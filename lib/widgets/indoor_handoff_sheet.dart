import 'package:flutter/material.dart';

import '../data/indoor_floor_coverage.dart';
import '../data/navigation_models.dart';

/// Building arrival copy. Direction to a room, never a walkable indoor route.
class IndoorHandoffSheet extends StatelessWidget {
  const IndoorHandoffSheet({
    super.key,
    required this.destination,
    required this.padding,
    required this.onScan,
    required this.onBack,
  });

  final NaviDestination destination;
  final EdgeInsets padding;
  final VoidCallback onScan;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final floor = destination.floorNumber;
    final covered = indoorScanCovered(destination.buildingCode, floor);
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Building reached',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            Text('Continue indoors to ${destination.name}.'),
            const Text('Direction to the room, not turn-by-turn.'),
            const Text(
              'Stairs, elevators, and mobility routing are unavailable.',
            ),
            if (!covered)
              Text(
                floor == null || floor.isEmpty
                    ? 'Indoor scanning is not available for this building.'
                    : 'Floor $floor is not scanned.',
              ),
            if (covered &&
                destination.indoorDestinationId?.trim().isNotEmpty != true)
              const Text(
                'No saved door position. You can still scan to find your position.',
              ),
            if (covered)
              FilledButton(onPressed: onScan, child: const Text('Scan AR')),
            TextButton(onPressed: onBack, child: const Text('Return to map')),
          ],
        ),
      ),
    );
  }
}
