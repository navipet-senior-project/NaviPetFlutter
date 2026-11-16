import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navipet/data/auth_token_provider.dart';
import 'package:navipet/data/pet_gems_gateway.dart';

class _Auth implements AuthTokenProvider {
  final refreshes = <bool>[];
  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? 'fresh' : 'old';
  }
}

class _NoSession implements AuthTokenProvider {
  @override
  Future<String?> token({bool forceRefresh = false}) async => null;
}

http.Response _json(Object value, int status) =>
    http.Response(jsonEncode(value), status);

void main() {
  test('fetches wallet and catalogue with the user token', () async {
    final paths = <String>[];
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test/',
      auth: _Auth(),
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer old');
        if (request.url.path == '/pet/gems') {
          return _json({
            'balance': 35,
            'equippedOutfit': 'hat',
            'ownedOutfits': ['hat'],
          }, 200);
        }
        return _json({
          'costumes': [
            {
              'id': 'hat',
              'name': 'Hat',
              'price': 20,
              'assetReference': 'hat.png',
              'owned': true,
            },
          ],
        }, 200);
      }),
    );
    expect((await gateway.getGems()).balance, 35);
    expect((await gateway.getCostumes()).single.owned, isTrue);
    expect(paths, ['/pet/gems', '/pet/costumes']);
  });

  test('buy reports the backend shortfall without changing it', () async {
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test',
      auth: _Auth(),
      client: MockClient((request) async {
        expect(request.url.path, '/pet/costumes/buy');
        expect(jsonDecode(request.body), {'outfitId': 'hat', 'equip': false});
        return _json({
          'error': {
            'code': 'INSUFFICIENT_GEMS',
            'message': 'Not enough gems',
            'shortfall': 7,
          },
        }, 409);
      }),
    );
    await expectLater(
      gateway.buy('hat'),
      throwsA(
        isA<PetGemsException>().having(
          (error) => error.shortfall,
          'shortfall',
          7,
        ),
      ),
    );
  });

  test('a malformed success body becomes a PetGemsException', () async {
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test',
      auth: _Auth(),
      client: MockClient((request) async => _json({'balance': 'many'}, 200)),
    );
    await expectLater(
      gateway.getGems(),
      throwsA(
        isA<PetGemsException>().having(
          (error) => error.message,
          'message',
          'The pet server returned an invalid response.',
        ),
      ),
    );
  });

  test('buy and equip read the balance and equipped outfit', () async {
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test',
      auth: _Auth(),
      client: MockClient(
        (request) async => _json({'balance': 12, 'equippedOutfit': 'hat'}, 200),
      ),
    );
    for (final wallet in [
      await gateway.buy('hat', equip: true),
      await gateway.equip('hat'),
    ]) {
      expect(wallet.balance, 12);
      expect(wallet.equippedOutfit, 'hat');
    }
  });

  test('a signed-out user never reaches the network', () async {
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test',
      auth: _NoSession(),
      client: MockClient((request) async => fail('no request expected')),
    );
    await expectLater(
      gateway.getGems(),
      throwsA(
        isA<PetGemsException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });

  test('retries a stale token once for the daily login reward', () async {
    final auth = _Auth();
    final gateway = HttpPetGemsGateway(
      baseUrl: 'https://api.test',
      auth: auth,
      client: MockClient((request) async {
        expect(request.url.path, '/pet/rewards/daily-login');
        return request.headers['authorization'] == 'Bearer old'
            ? _json({
                'error': {'message': 'Expired'},
              }, 401)
            : _json({'balance': 5, 'earned': 5}, 200);
      }),
    );
    expect(await gateway.claimDailyLogin(), 5);
    expect(auth.refreshes, [false, true]);
  });

  test(
    'sends navigation coordinates and trip id to the reward endpoints',
    () async {
      final paths = <String>[];
      final gateway = HttpPetGemsGateway(
        baseUrl: 'https://api.test',
        auth: _Auth(),
        client: MockClient((request) async {
          paths.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['latitude'], 33.78);
          expect(body['longitude'], -118.11);
          if (request.url.path.endsWith('/start')) {
            expect(body['destinationId'], 'building');
            return _json({'tripId': 'trip'}, 200);
          }
          expect(body['tripId'], 'trip');
          return _json({'balance': 6, 'earned': 1}, 200);
        }),
      );
      final trip = await gateway.startNavigation('building', 33.78, -118.11);
      expect(await gateway.finishNavigation(trip, 33.78, -118.11), 1);
      expect(paths, [
        '/pet/rewards/navigation/start',
        '/pet/rewards/navigation/finish',
      ]);
    },
  );
}
