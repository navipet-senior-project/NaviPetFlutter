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

  group('updateProfile', () {
    test(
      'sends JSON with only the provided fields when there is no avatar',
      () async {
        await gateway(
          (_) => _json(_profile(), 200),
        ).updateProfile(displayName: 'Jane');

        final request = requests.single;
        expect(request.method, 'PATCH');
        expect(request.url.path, '/profiles/me');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {'displayName': 'Jane'});
      },
    );

    test('sends the avatar and fields as one multipart PATCH', () async {
      final profile =
          await gateway(
            (_) => _json(_profile(avatarUrl: 'https://cdn.test/new.png'), 200),
          ).updateProfile(
            displayName: 'Jane',
            role: 'student',
            avatarBytes: [0x89, 0x50, 0x4E, 0x47],
          );

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/profiles/me');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="avatar"; filename="avatar.png"'));
      expect(body, contains(latin1.decode([0x89, 0x50, 0x4E, 0x47])));
      expect(body, contains('name="displayName"'));
      expect(body, contains('name="role"'));
      expect(body, isNot(contains('avatar${'Upload'}Id')));
      expect(profile.avatarUrl, 'https://cdn.test/new.png');
    });

    test('an avatar-only update sends no text fields', () async {
      await gateway(
        (_) => _json(_profile(), 200),
      ).updateProfile(avatarBytes: [1, 2, 3]);

      final body = latin1.decode(requests.single.bodyBytes);
      expect(body, contains('name="avatar"'));
      expect(body, isNot(contains('name="displayName"')));
      expect(body, isNot(contains('name="role"')));
    });

    test('rebuilds the multipart request for the 401 retry', () async {
      var calls = 0;
      await gateway(
        (_) => ++calls == 1 ? _error(401, 'expired') : _json(_profile(), 200),
        auth: FakeAuth(['stale', 'fresh']),
      ).updateProfile(avatarBytes: [1, 2, 3]);

      expect(requests, hasLength(2));
      expect(latin1.decode(requests.last.bodyBytes), contains('name="avatar"'));
      expect(requests.last.headers['Authorization'], 'Bearer fresh');
    });

    for (final status in [400, 413, 415, 422, 502, 503]) {
      test('maps $status to a typed exception', () async {
        await expectLater(
          gateway(
            (_) => _error(status, 'nope'),
          ).updateProfile(avatarBytes: [1]),
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

    test('sends and reads the selected role', () async {
      final profile = await gateway(
        (_) => _json({
          'profile': {'displayName': 'Jane', 'role': 'professor'},
        }, 200),
      ).updateProfile(role: 'professor');

      expect(jsonDecode(requests.single.body), {'role': 'professor'});
      expect(profile.role, 'professor');
    });
  });
}
