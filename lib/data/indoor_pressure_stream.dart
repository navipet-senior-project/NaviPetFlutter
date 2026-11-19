import 'package:flutter/services.dart';

/// Live phone barometer readings in pascals. Phones without a barometer return
/// an empty stream, allowing the floor estimator to use other evidence.
class IndoorPressureStream {
  IndoorPressureStream({EventChannel? channel})
    : _channel = channel ?? const EventChannel('navipet/indoor_pressure');

  final EventChannel _channel;

  Stream<double> get pascals => _channel
      .receiveBroadcastStream()
      .where((event) => event is num)
      .map((event) => (event as num).toDouble())
      .where((value) => value.isFinite && value >= 30000 && value <= 120000);
}
