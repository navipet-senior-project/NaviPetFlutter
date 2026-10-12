import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/profile_gateway.dart';

class FakeAuth implements AuthTokenProvider {
  FakeAuth(this.tokens);
  final List<String?> tokens;
  final List<bool> refreshCalls = [];
  int _index = 0;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshCalls.add(forceRefresh);
    final value = tokens[_index.clamp(0, tokens.length - 1)];
    _index++;
    return value;
  }
}

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int status, String message) => _json({
  'error': {'code': 'X', 'message': message, 'requestId': 'r'},
}, status);

Map<String, dynamic> _profile({String? avatarUrl}) => {
  'profile': {
    'displayName': 'Jane',
    'email': 'a@b.c',
    'role': 'student',
    'avatarUrl': avatarUrl,
  },
};

void main() {
  late List<http.Request> requests;

  HttpProfileGateway gateway(
    http.Response Function(http.Request request) handler, {
    AuthTokenProvider? auth,
  }) {
    requests = [];
    return HttpProfileGateway(
      baseUrl: 'https://api.test/',
      auth: auth ?? FakeAuth(['token-1']),
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  group('fetchProfile', () {
    test('sends the bearer token and reads the signed avatar URL', () async {
      final profile = await gateway(
        (_) =>
            _json(_profile(avatarUrl: 'https://cdn.test/a.webp?token=1'), 200),
      ).fetchProfile();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), 'https://api.test/profiles/me');
      expect(requests.single.headers['Authorization'], 'Bearer token-1');
      expect(profile.displayName, 'Jane');
      expect(profile.role, 'student');
      expect(profile.avatarUrl, 'https://cdn.test/a.webp?token=1');
    });

    test('treats a null avatarUrl as no avatar', () async {
      final profile = await gateway(
        (_) => _json(_profile(), 200),
      ).fetchProfile();
      expect(profile.avatarUrl, isNull);
    });

    test('retries once with a refreshed token after a 401', () async {
      final auth = FakeAuth(['stale', 'fresh']);
      var calls = 0;
      final profile = await gateway((request) {
        calls++;
        return calls == 1 ? _error(401, 'expired') : _json(_profile(), 200);
      }, auth: auth).fetchProfile();

      expect(profile.displayName, 'Jane');
      expect(auth.refreshCalls, [false, true]);
      expect(requests.last.headers['Authorization'], 'Bearer fresh');
    });

    test('fails with 401 without calling the server when signed out', () async {
      final call = gateway(
        (_) => _json(_profile(), 200),
        auth: FakeAuth([null]),
      ).fetchProfile();

      await expectLater(
        call,
        throwsA(
          isA<ProfileApiException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(requests, isEmpty);
    });

    test('maps a 404 to a typed exception', () async {
      await expectLater(
        gateway((_) => _error(404, 'Profile not found.')).fetchProfile(),
        throwsA(
          isA<ProfileApiException>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.message, 'message', 'Profile not found.'),
        ),
      );
    });

    test('maps an unreachable server to status 0', () async {
      final unreachable = HttpProfileGateway(
        baseUrl: 'https://api.test',
        auth: FakeAuth(['t']),
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      await expectLater(
        unreachable.fetchProfile(),
        throwsA(
          isA<ProfileApiException>().having((e) => e.statusCode, 'status', 0),
        ),
      );
    });
  });

  group('uploadAvatar', () {
    test('posts the bytes as multipart in the avatar field', () async {
      final upload = await gateway(
        (_) => _json({
          'uploadId': '6f1c1f0e-0000-4000-8000-000000000001',
          'avatarUrl': 'https://cdn.test/pending.jpg?token=1',
        }, 200),
      ).uploadAvatar(bytes: [0xFF, 0xD8, 0xFF, 0xE0], filename: 'me.jpg');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/profiles/me/avatar');
      expect(request.headers['Authorization'], 'Bearer token-1');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="avatar"; filename="me.jpg"'));
      expect(body, contains(latin1.decode([0xFF, 0xD8, 0xFF, 0xE0])));
      expect(upload.uploadId, '6f1c1f0e-0000-4000-8000-000000000001');
      expect(upload.avatarUrl, 'https://cdn.test/pending.jpg?token=1');
    });

    test('rebuilds the multipart request for the 401 retry', () async {
      var calls = 0;
      final upload = await gateway(
        (request) {
          calls++;
          return calls == 1
              ? _error(401, 'expired')
              : _json({
                  'uploadId': 'u1',
                  'avatarUrl': 'https://cdn.test/p',
                }, 200);
        },
        auth: FakeAuth(['stale', 'fresh']),
      ).uploadAvatar(bytes: [1, 2, 3], filename: 'me.png');

      expect(upload.uploadId, 'u1');
      expect(requests, hasLength(2));
      expect(latin1.decode(requests.last.bodyBytes), contains('name="avatar"'));
    });

    for (final status in [400, 413, 415, 502, 503]) {
      test('maps $status to a typed exception', () async {
        await expectLater(
          gateway(
            (_) => _error(status, 'nope'),
          ).uploadAvatar(bytes: [1], filename: 'x.heic'),
          throwsA(
            isA<ProfileApiException>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
      });
    }

    test('rejects a response without an uploadId', () async {
      await expectLater(
        gateway(
          (_) => _json({'avatarUrl': 'https://cdn.test/p'}, 200),
        ).uploadAvatar(bytes: [1], filename: 'x.jpg'),
        throwsA(isA<ProfileApiException>()),
      );
    });
  });

  group('updateProfile', () {
    test('patches only the provided fields', () async {
      final profile = await gateway(
        (_) => _json(_profile(avatarUrl: 'https://cdn.test/new.jpg'), 200),
      ).updateProfile(avatarUploadId: 'u1');

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/profiles/me');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'avatarUploadId': 'u1'});
      expect(profile.avatarUrl, 'https://cdn.test/new.jpg');
    });

    test('sends the display name alongside the upload', () async {
      await gateway(
        (_) => _json(_profile(), 200),
      ).updateProfile(displayName: 'Jane', avatarUploadId: 'u1');

      expect(jsonDecode(requests.single.body), {
        'displayName': 'Jane',
        'avatarUploadId': 'u1',
      });
    });

    test('sends and reads the selected role', () async {
      final profile = await gateway(
        (_) => _json({
          'profile': {'displayName': 'Jane', 'role': 'professor'},
        }, 200),
      ).updateProfile(role: 'professor');

      expect(jsonDecode(requests.single.body), {'role': 'professor'});
      expect(profile.role, 'professor');
    });

    test('surfaces a 404 for an upload that no longer exists', () async {
      await expectLater(
        gateway(
          (_) => _error(404, 'Avatar upload not found.'),
        ).updateProfile(avatarUploadId: 'gone'),
        throwsA(
          isA<ProfileApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });

  group('discardAvatarUpload', () {
    test('deletes the pending upload by id', () async {
      await gateway(
        (_) => http.Response('', 204),
      ).discardAvatarUpload('6f1c1f0e-0000-4000-8000-000000000001');

      expect(requests.single.method, 'DELETE');
      expect(
        requests.single.url.path,
        '/profiles/me/avatar/6f1c1f0e-0000-4000-8000-000000000001',
      );
      expect(requests.single.headers['Authorization'], 'Bearer token-1');
    });

    test('treats 404 (already gone) as success', () async {
      await gateway(
        (_) => _error(404, 'Temporary avatar not found.'),
      ).discardAvatarUpload('u1');
    });

    test('throws for other failures', () async {
      await expectLater(
        gateway((_) => _error(502, 'down')).discardAvatarUpload('u1'),
        throwsA(
          isA<ProfileApiException>().having((e) => e.statusCode, 'status', 502),
        ),
      );
    });
  });
}
