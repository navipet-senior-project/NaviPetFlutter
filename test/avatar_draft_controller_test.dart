import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
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

  test('picking again evicts the previous preview from the image cache', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([4, 5, 6]);
    final draft = AvatarDraftController()..pick(first);
    final previous = MemoryImage(first);
    imageCache.putIfAbsent(
      previous,
      () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
    );
    addTearDown(imageCache.clear);

    draft.pick(second);

    expect(imageCache.containsKey(previous), isFalse);
    expect(draft.pendingBytes, second);
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
