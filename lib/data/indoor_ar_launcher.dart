import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'indoor_ar_contract.dart';

/// Opens the fullscreen AR session for one destination and completes when
/// the student is back in the app.
abstract interface class IndoorArLauncher {
  Future<IndoorArResult> launch(IndoorArRequest request);
}

/// Talks to `IndoorArChannel` in the Android host (`MainActivity`). The host
/// answers every call with a result JSON string, including builds without
/// the Unity library (`unavailable`).
class AndroidIndoorArLauncher implements IndoorArLauncher {
  AndroidIndoorArLauncher({MethodChannel? channel, bool? isAndroid})
    : _channel = channel ?? const MethodChannel(channelName),
      _isAndroid =
          isAndroid ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const channelName = 'navipet/indoor_ar';

  final MethodChannel _channel;
  final bool _isAndroid;

  @override
  Future<IndoorArResult> launch(IndoorArRequest request) async {
    if (!_isAndroid) return const IndoorArResult.unavailable();
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>(
        'launch',
        jsonEncode(request.toJson()),
      );
    } on MissingPluginException {
      return const IndoorArResult.unavailable();
    } on PlatformException {
      // The host never raises on purpose; treat it like a bad reply.
      return const IndoorArResult.badResult();
    }
    return raw is String
        ? IndoorArResult.decode(raw)
        : const IndoorArResult.badResult();
  }
}

/// Test double. Returns [result] and records every request.
class FakeIndoorArLauncher implements IndoorArLauncher {
  FakeIndoorArLauncher({this.result = const IndoorArResult.unavailable()});

  IndoorArResult result;
  final requests = <IndoorArRequest>[];

  @override
  Future<IndoorArResult> launch(IndoorArRequest request) async {
    requests.add(request);
    return result;
  }
}
