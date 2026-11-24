import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/ar_floor_pressure_source.dart';
import 'package:navipet/data/floor_pressure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'AR pressure source keeps the native capture time on $platform',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        const channel = MethodChannel('navipet/floor_pressure');
        const codec = StandardMethodCodec();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        });

        final readings = <PressureReading>[];
        final subscription = const ArFloorPressureSource().readings().listen(
          readings.add,
        );
        const capturedAt = 1767225600123456;
        await messenger.handlePlatformMessage(
          channel.name,
          codec.encodeSuccessEnvelope([1013.25, capturedAt]),
          null,
        );
        expect(readings.single.hPa, 1013.25);
        expect(readings.single.timestamp.microsecondsSinceEpoch, capturedAt);
        await subscription.cancel();
        expect(calls, ['listen', 'cancel']);
      },
    );
  }
}
