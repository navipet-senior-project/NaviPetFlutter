import 'package:flutter/foundation.dart';

import 'profile_gateway.dart';

/// Holds the one unsaved avatar on the edit-profile screen. Nothing reaches
/// the server until Save sends the bytes with the profile update, so there
/// is nothing to discard when the user leaves without saving.
class AvatarDraftController extends ChangeNotifier {
  static const maxBytes = 5 * 1024 * 1024;
  static const tooLargeMessage = 'Image must be 5 MB or smaller.';
  static const unsupportedMessage = 'Use a JPEG, PNG, or WebP image.';

  Uint8List? _bytes;

  Uint8List? get pendingBytes => _bytes;

  /// Makes [bytes] the draft. Returns the user-facing error instead when the
  /// image is too large; the earlier draft then stays.
  String? pick(Uint8List bytes) {
    if (bytes.length > maxBytes) return tooLargeMessage;
    _bytes = bytes;
    notifyListeners();
    return null;
  }

  /// Copy for a failed avatar save, or `null` when the caller's own generic
  /// message fits better.
  static String? messageFor(ProfileApiException error) =>
      switch (error.statusCode) {
        413 => tooLargeMessage,
        415 => unsupportedMessage,
        0 || 408 => error.message,
        _ => null,
      };
}
