import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/elbee_gateway.dart';
import 'package:navipet/data/elbee_reply.dart';
import 'package:navipet/data/pet_gems_gateway.dart';
import 'package:navipet/data/user_account.dart';
import 'package:navipet/screens/pet_customization_screen.dart';
import 'package:navipet/screens/pet_home_screen.dart';
import 'package:provider/provider.dart';

import 'support/flow_fakes.dart' as harness;

const _costumes = [
  PetCostume(
    id: 'csulb_tee',
    name: 'CSULB Tee',
    price: 20,
    assetReference: 'csulb_tee',
    owned: false,
  ),
  PetCostume(
    id: 'shades',
    name: 'Shades',
    price: 15,
    assetReference: 'shades',
    owned: false,
  ),
];

/// Stands in for the backend's pet endpoints. [balance] is the server's truth.
class _Gateway implements PetGemsGateway {
  int balance = 40;
  Set<String> owned = {};
  String? equipped;
  Object? claimError = const PetGemsException('Resource not found', 404);
  Object? walletError;
  Future<PetWallet> Function()? walletOverride;
  final buys = <String>[];

  @override
  Future<PetWallet> getGems() async {
    final override = walletOverride;
    if (override != null) return override();
    if (walletError != null) throw walletError!;
    return PetWallet(balance, equipped, {...owned});
  }

  @override
  Future<List<PetCostume>> getCostumes() async => [
    for (final item in _costumes)
      PetCostume(
        id: item.id,
        name: item.name,
        price: item.price,
        assetReference: item.assetReference,
        owned: owned.contains(item.id),
      ),
  ];

  @override
  Future<PetWallet> buy(String outfitId, {bool equip = false}) async {
    buys.add(outfitId);
    final price = _costumes.firstWhere((item) => item.id == outfitId).price;
    if (balance < price) {
      throw PetGemsException(
        'Not enough gems',
        409,
        shortfall: price - balance,
      );
    }
    balance -= price;
    owned.add(outfitId);
    return PetWallet(balance, equipped, const {});
  }

  @override
  Future<PetWallet> equip(String outfitId) async =>
      PetWallet(balance, equipped = outfitId, const {});

  @override
  Future<int> claimDailyLogin() async {
    if (claimError != null) throw claimError!;
    return 0;
  }

  @override
  Future<String> startNavigation(String id, double lat, double lng) async =>
      'trip';

  @override
  Future<int> finishNavigation(String id, double lat, double lng) async => 0;
}

class _AppState extends AppState {
  _AppState(PetGemsGateway gateway) : super(petGemsGateway: gateway);

  @override
  bool get isAuthenticated => true;

  @override
  UserAccount? get activeUser => const UserAccount(
    id: 'user',
    name: 'Alex',
    email: 'alex@example.com',
    avatarColor: Color(0xFF002B5B),
    gems: 0,
    level: 1,
  );
}

class _Elbee implements ElbeeGateway {
  @override
  Future<ElbeeReply> ask(String question, {required bool scheduleConsent}) =>
      throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, AppState state, String location) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/pet',
        builder: (context, state) => const PetHomeScreen(),
        routes: [
          GoRoute(
            path: 'shop',
            builder: (context, state) => const PetCustomizationScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider.value(value: harness.build()),
        Provider<ElbeeGateway>.value(value: _Elbee()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('wallet state', () {
    test(
      'loads from the server even when the reward endpoint is missing',
      () async {
        final state = _AppState(_Gateway());
        expect(state.petLoaded, isFalse);

        await state.claimDailyLoginGems();

        expect(state.petLoaded, isTrue);
        expect(state.petError, isNull);
        expect(state.points, 40);
        expect(state.costumes.map((item) => item.id), ['csulb_tee', 'shades']);
      },
    );

    test(
      'a failed load is reported and not shown as a loaded wallet',
      () async {
        final gateway = _Gateway()
          ..walletError = const PetGemsException(
            'Sign in to use pet gems.',
            401,
          );
        final state = _AppState(gateway);

        await state.refreshPoints();

        expect(state.petLoaded, isFalse);
        expect(state.petBusy, isFalse);
        expect(state.petError, 'Sign in to use pet gems.');
      },
    );

    test('an older response never overwrites a newer one', () async {
      final older = Completer<PetWallet>();
      final newer = Completer<PetWallet>();
      final gateway = _Gateway();
      final state = _AppState(gateway);

      gateway.walletOverride = () => older.future;
      final first = state.refreshPoints();
      gateway.walletOverride = () => newer.future;
      final second = state.refreshPoints();

      newer.complete(const PetWallet(50, null, {}));
      await second;
      older.complete(const PetWallet(10, null, {}));
      await first;

      expect(state.points, 50);
      expect(state.petBusy, isFalse);
    });

    test('buying takes the new balance from the server', () async {
      final gateway = _Gateway();
      final state = _AppState(gateway);
      await state.refreshPoints();

      await state.buyOutfit('csulb_tee');

      expect(gateway.buys, ['csulb_tee']);
      expect(state.points, 20);
      expect(state.ownedOutfits, {'csulb_tee'});
    });

    test(
      'insufficient gems reports the shortfall and reloads the balance',
      () async {
        final gateway = _Gateway();
        final state = _AppState(gateway);
        await state.refreshPoints();
        expect(state.points, 40);
        gateway.balance = 12; // spent on another device since the last load

        await expectLater(
          state.buyOutfit('csulb_tee'),
          throwsA(
            isA<PetGemsException>()
                .having((error) => error.statusCode, 'status', 409)
                .having((error) => error.shortfall, 'shortfall', 8),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(state.points, 12);
        expect(state.ownedOutfits, isEmpty);
      },
    );
  });

  group('screens', () {
    testWidgets('Pet Home shows a spinner, then the server balance', (
      tester,
    ) async {
      final state = _AppState(_Gateway());
      await _pump(tester, state, '/pet');
      expect(find.text('40'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await state.claimDailyLoginGems();
      await tester.pump();

      expect(find.text('40'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Shop lists server prices and explains a 409 shortfall', (
      tester,
    ) async {
      final gateway = _Gateway();
      final state = _AppState(gateway);
      await state.refreshPoints();
      await _pump(tester, state, '/pet/shop');

      expect(find.text('Buy 20 gems'), findsOneWidget);
      expect(find.text('Buy 15 gems'), findsOneWidget);
      gateway.balance = 12; // the app's 40 is stale

      await tester.tap(find.byKey(const ValueKey('shop-csulb_tee')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not buy CSULB Tee: Not enough gems (8 more gems needed)',
        ),
        findsOneWidget,
      );
      expect(find.text('Need 8 more gems'), findsOneWidget);
      expect(find.text('Buy 15 gems'), findsNothing);
      expect(find.text('Need 3 more gems'), findsOneWidget);
    });
  });
}
