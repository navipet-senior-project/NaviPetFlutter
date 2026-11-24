import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'floor_pressure.dart';

class ArFloorPressureSource implements PressureSource {
  const ArFloorPressureSource();

  static final _mobileReadings = const EventChannel('navipet/floor_pressure')
      .receiveBroadcastStream()
      .map((event) {
        final values = event as List<Object?>;
        return PressureReading(
          hPa: (values[0] as num).toDouble(),
          timestamp: DateTime.fromMicrosecondsSinceEpoch(values[1] as int),
        );
      })
      .handleError((Object e) => throw classifyPressureError(e));

  @override
  Stream<PressureReading> readings() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      return _mobileReadings;
    }
    return const SensorsPlusPressureSource().readings();
  }
}
