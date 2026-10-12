import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/avatar_draft_controller.dart';
import 'package:navipet/data/profile_gateway.dart';

/// Uploads stay pending until the test completes them, so the order in which
/// responses land can be controlled.
class FakeProfileGateway implements ProfileGateway {
  final List<Completer<AvatarUpload>> uploads = [];
  final List<String> discarded = [];

  @override
  Future<AvatarUpload> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) {
    final completer = Completer<AvatarUpload>();
    uploads.add(completer);
    return completer.future;
  }

  @override
  Future<void> discardAvatarUpload(String uploadId) async {
    discarded.add(uploadId);
  }

  @override
  Future<RemoteProfile> fetchProfile() => throw UnimplementedError();

  @override
  Future<RemoteProfile> updateProfile({
    String? displayName,
    String? avatarUploadId,
    String? role,
  }) => throw UnimplementedError();
}

AvatarUpload _upload(String id) =>
    AvatarUpload(uploadId: id, avatarUrl: 'https://cdn.test/$id');

void main() {
  late FakeProfileGateway gateway;
  late AvatarDraftController draft;

  setUp(() {
    gateway = FakeProfileGateway();
    draft = AvatarDraftController(gateway);
  });

  test('a finished upload becomes the pending preview', () async {
    final pick = draft.upload([1], 'a.jpg');
    expect(draft.isUploading, isTrue);

    gateway.uploads.single.complete(_upload('a'));
    expect(await pick, isNull);

    expect(draft.isUploading, isFalse);
    expect(draft.pendingUploadId, 'a');
    expect(draft.previewUrl, 'https://cdn.test/a');
  });

  test('picking again discards the previous finished upload', () async {
    final first = draft.upload([1], 'a.jpg');
    gateway.uploads[0].complete(_upload('a'));
    await first;

    final second = draft.upload([2], 'b.jpg');
    expect(gateway.discarded, ['a']);
    expect(draft.pendingUploadId, isNull);
    expect(draft.previewUrl, isNull);

    gateway.uploads[1].complete(_upload('b'));
    await second;
    expect(draft.pendingUploadId, 'b');
  });

  test('a superseded upload that lands late is discarded, not shown', () async {
    final first = draft.upload([1], 'a.jpg');
    final second = draft.upload([2], 'b.jpg');

    gateway.uploads[1].complete(_upload('b'));
    await second;
    gateway.uploads[0].complete(_upload('a'));
    await first;

    expect(draft.pendingUploadId, 'b');
    expect(draft.previewUrl, 'https://cdn.test/b');
    expect(gateway.discarded, ['a']);
  });

  test(
    'a superseded upload landing late does not end the newer upload',
    () async {
      final first = draft.upload([1], 'a.jpg');
      unawaited(draft.upload([2], 'b.jpg'));

      gateway.uploads[0].complete(_upload('a'));
      await first;

      expect(draft.isUploading, isTrue);
      expect(draft.pendingUploadId, isNull);
    },
  );

  test('a superseded failure is not reported', () async {
    final first = draft.upload([1], 'a.jpg');
    unawaited(draft.upload([2], 'b.jpg'));

    gateway.uploads[0].completeError(
      const ProfileApiException(message: 'too big', statusCode: 413),
    );

    expect(await first, isNull);
    expect(draft.errorMessage, isNull);
  });

  test('maps 413 and 415 to their messages', () async {
    final big = draft.upload([1], 'a.jpg');
    gateway.uploads[0].completeError(
      const ProfileApiException(message: 'x', statusCode: 413),
    );
    expect(await big, AvatarDraftController.tooLargeMessage);

    final heic = draft.upload([1], 'a.heic');
    gateway.uploads[1].completeError(
      const ProfileApiException(message: 'x', statusCode: 415),
    );
    expect(await heic, AvatarDraftController.unsupportedMessage);
    expect(draft.errorMessage, AvatarDraftController.unsupportedMessage);
    expect(draft.isUploading, isFalse);
  });

  test('other upload failures get the generic message', () async {
    final pick = draft.upload([1], 'a.jpg');
    gateway.uploads[0].completeError(
      const ProfileApiException(
        message: 'Profile storage unavailable.',
        statusCode: 502,
      ),
    );
    expect(await pick, AvatarDraftController.failedMessage);
  });

  test('rejects an image over 5 MB without uploading it', () async {
    final error = await draft.upload(
      List.filled(AvatarDraftController.maxBytes + 1, 0),
      'huge.jpg',
    );

    expect(error, AvatarDraftController.tooLargeMessage);
    expect(gateway.uploads, isEmpty);
    expect(draft.isUploading, isFalse);
  });

  test('disposing discards the pending upload', () async {
    final pick = draft.upload([1], 'a.jpg');
    gateway.uploads[0].complete(_upload('a'));
    await pick;

    draft.dispose();

    expect(gateway.discarded, ['a']);
  });

  test('disposing mid-upload discards the upload when it lands', () async {
    final pick = draft.upload([1], 'a.jpg');
    draft.dispose();

    gateway.uploads[0].complete(_upload('a'));
    await pick;

    expect(gateway.discarded, ['a']);
  });

  test('an upload taken for commit is not discarded on dispose', () async {
    final pick = draft.upload([1], 'a.jpg');
    gateway.uploads[0].complete(_upload('a'));
    await pick;

    expect(draft.takeForCommit(), 'a');
    draft.dispose();

    expect(gateway.discarded, isEmpty);
  });

  test('a failed commit hands the upload back for a retry', () async {
    final pick = draft.upload([1], 'a.jpg');
    gateway.uploads[0].complete(_upload('a'));
    await pick;

    final id = draft.takeForCommit()!;
    draft.restoreAfterFailedCommit(id, expired: false);

    expect(draft.pendingUploadId, 'a');
    draft.dispose();
    expect(gateway.discarded, ['a']);
  });

  test(
    'an expired upload is dropped and the user asked to pick again',
    () async {
      final pick = draft.upload([1], 'a.jpg');
      gateway.uploads[0].complete(_upload('a'));
      await pick;

      final id = draft.takeForCommit()!;
      draft.restoreAfterFailedCommit(id, expired: true);

      expect(draft.pendingUploadId, isNull);
      expect(draft.previewUrl, isNull);
      expect(draft.errorMessage, AvatarDraftController.expiredMessage);
      draft.dispose();
      expect(gateway.discarded, isEmpty);
    },
  );

  test('does not notify listeners after dispose', () async {
    var notifications = 0;
    draft.addListener(() => notifications++);
    final pick = draft.upload([1], 'a.jpg');
    final before = notifications;

    draft.dispose();
    gateway.uploads[0].complete(_upload('a'));
    await pick;

    expect(notifications, before);
  });
}
