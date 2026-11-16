import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/avatar_draft_controller.dart';
import 'package:navipet/data/profile_gateway.dart';

void main() {
  test('a picked image becomes the pending draft and notifies', () {
    final draft = AvatarDraftController();
    var notified = 0;
    draft.addListener(() => notified++);

    expect(draft.pick(Uint8List.fromList([1, 2, 3])), isNull);

    expect(draft.pendingBytes, [1, 2, 3]);
    expect(notified, 1);
  });

  test('rejects an image over 5 MB and keeps the earlier draft', () {
    final draft = AvatarDraftController()..pick(Uint8List.fromList([7]));

    final error = draft.pick(Uint8List(AvatarDraftController.maxBytes + 1));

    expect(error, AvatarDraftController.tooLargeMessage);
    expect(draft.pendingBytes, [7]);
  });

  test('maps save failures to copy', () {
    ProfileApiException e(int status) =>
        ProfileApiException(message: 'm$status', statusCode: status);

    expect(
      AvatarDraftController.messageFor(e(413)),
      AvatarDraftController.tooLargeMessage,
    );
    expect(
      AvatarDraftController.messageFor(e(415)),
      AvatarDraftController.unsupportedMessage,
    );
    expect(AvatarDraftController.messageFor(e(0)), 'm0');
    expect(AvatarDraftController.messageFor(e(408)), 'm408');
    expect(AvatarDraftController.messageFor(e(502)), isNull);
  });
}
