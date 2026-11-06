import 'dart:math' as math;

import 'location_service.dart';
import 'navigation_models.dart';
import 'route_progress.dart';

enum DestinationPresence { inside, outside, uncertain }

/// All GPS confirmation thresholds live here, shared by start and live arrival.
abstract final class ArrivalPolicy {
  static const maximumAge = Duration(seconds: 10);
  static const maximumAccuracyMeters = 20.0;
  static const consistentReadings = 2;
  static const boundaryHysteresisMeters = 2.0;
  static const approachMeters = 15.0;
}

/// A wall/accuracy overlap never confirms presence. Replayed fixes never vote.
class DestinationPresenceTracker {
  final List<(DateTime, DestinationPresence)> _samples = [];
  DateTime? _lastTimestamp;

  void reset() {
    _samples.clear();
    _lastTimestamp = null;
  }

  DestinationPresence valueAt(DateTime now) {
    _samples.removeWhere(
      (sample) =>
          sample.$1.isAfter(now) ||
          now.difference(sample.$1) > ArrivalPolicy.maximumAge,
    );
    if (_samples.length < ArrivalPolicy.consistentReadings) {
      return DestinationPresence.uncertain;
    }
    final candidate = _samples.last.$2;
    return _samples.every((sample) => sample.$2 == candidate)
        ? candidate
        : DestinationPresence.uncertain;
  }

  DestinationPresence add(
    BuildingFootprint? footprint,
    LocationReading reading,
    DateTime now,
  ) {
    final point = reading.coordinate;
    final timestamp = reading.timestamp;
    final accuracy = reading.accuracyMeters;
    if (footprint == null ||
        !reading.usable ||
        reading.isApproximate ||
        point == null ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        timestamp == null ||
        timestamp.isAfter(now) ||
        now.difference(timestamp) > ArrivalPolicy.maximumAge ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > ArrivalPolicy.maximumAccuracyMeters) {
      _samples.clear();
      return DestinationPresence.uncertain;
    }
    final signedGap = signedFootprintDistanceMeters(footprint, point);
    // Entry needs extra clearance; a confirmed side keeps its smaller margin.
    final confirmed = valueAt(now);
    final side = signedGap > 0
        ? DestinationPresence.inside
        : DestinationPresence.outside;
    final margin =
        math.max(accuracy, ArrivalPolicy.boundaryHysteresisMeters) +
        (confirmed == side ? 0 : ArrivalPolicy.boundaryHysteresisMeters);
    if (!signedGap.isFinite || signedGap.abs() <= margin) {
      _samples.clear();
      return DestinationPresence.uncertain;
    }
    if (_lastTimestamp != null && !timestamp.isAfter(_lastTimestamp!)) {
      if (timestamp.isBefore(_lastTimestamp!) ||
          (_samples.isNotEmpty && _samples.last.$2 != side)) {
        _samples.clear();
        return DestinationPresence.uncertain;
      }
      return valueAt(now);
    }
    _lastTimestamp = timestamp;
    if (_samples.isNotEmpty && _samples.last.$2 != side) _samples.clear();
    _samples.add((timestamp, side));
    if (_samples.length > ArrivalPolicy.consistentReadings) {
      _samples.removeAt(0);
    }
    return valueAt(now);
  }
}
