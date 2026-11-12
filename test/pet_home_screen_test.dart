import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/course_class.dart';
import 'package:navipet/data/elbee_gateway.dart';
import 'package:navipet/data/elbee_reply.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/user_account.dart';
import 'package:navipet/screens/pet_customization_screen.dart';
import 'package:navipet/screens/pet_home_screen.dart';
import 'package:navipet/screens/pet_pack_screen.dart';
import 'package:navipet/screens/pet_quests_screen.dart';
import 'package:navipet/widgets/elbee_sheet.dart';
import 'package:navipet/widgets/bottom_nav_bar.dart';
import 'package:provider/provider.dart';

import 'support/flow_fakes.dart' as harness;

const _everyDay = [1, 2, 3, 4, 5, 6, 7];

const _inPerson = CourseClass(
  id: '1',
  courseCode: 'CECS 491A',
  courseName: 'Senior Project',
  building: 'Vivian Engineering Center',
  room: '308',
  weekdays: _everyDay,
  startTime: '10:00',
  endTime: '11:15',
  latitude: 33.78,
  longitude: -118.11,
);

const _online = CourseClass(
  id: '2',
  courseCode: 'CECS 453',
  courseName: 'Mobile Apps',
  building: '',
  room: '',
  weekdays: _everyDay,
  startTime: '13:00',
  endTime: '14:15',
  latitude: 33.78,
  longitude: -118.11,
  isOnline: true,
);

class _FakeAppState extends AppState {
  _FakeAppState({
    List<CourseClass> fakeClasses = const [_inPerson, _online],
    this.busy = false,
    this.error,
    Set<String> owned = const {},
    this.equipped,
    this.refreshThrows = false,
    this.equipThrows = false,
    this.claimResult = TaskClaimResult.claimed,
    this.gems = 120,
    this.onlineRunning = false,
  }) : _classes = fakeClasses,
       owned = {...owned};

  final List<CourseClass> _classes;
  final bool busy;
  final String? error;
  final Set<String> owned;
  String? equipped;
  final bool refreshThrows;
  final bool equipThrows;
  final TaskClaimResult claimResult;
  final int gems;
  bool onlineRunning;
  int _durationReads = 0;

  int refreshes = 0;
  final equipCalls = <String>[];
  final buyCalls = <String>[];
  int claims = 0;

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

  @override
  List<CourseClass> get classes => _classes;

  @override
  bool get classesBusy => busy;

  @override
  String? get classesError => error;

  @override
  int get points => gems;

  @override
  Set<String> get ownedOutfits => owned;

  @override
  String? get equippedOutfit => equipped;

  @override
  int completionCountFor(String classId) => classId == '1' ? 7 : 0;

  @override
  bool get hasRunningOnlineSession => onlineRunning;

  @override
  bool onlineSessionRunning(String classId) => onlineRunning && classId == '2';

  @override
  Duration onlineSessionDuration(String classId) =>
      Duration(seconds: ++_durationReads);

  @override
  Duration onlineSessionRequirement(CourseClass course) =>
      const Duration(minutes: 30);

  @override
  void startOnlineSession(String classId) {
    onlineRunning = true;
    notifyListeners();
  }

  @override
  List<DailyClassTask> dailyTasks([DateTime? day]) => [
    for (final course in _classes)
      DailyClassTask(
        course: course,
        kind: course.isOnline ? 'attend_online' : 'attend',
        label: course.isOnline
            ? 'Attend ${course.courseCode} online'
            : 'Go to ${course.locationLabel} for ${course.courseCode}',
        reward: course.isOnline ? 5 : 10,
        done: course.isOnline && !onlineRunning,
      ),
  ];

  @override
  Future<void> refreshClasses() async {
    refreshes++;
    if (refreshThrows) throw Exception('offline');
  }

  @override
  Future<void> equipOutfit(String outfitId) async {
    equipCalls.add(outfitId);
    if (equipThrows) throw Exception('offline');
    equipped = outfitId;
    notifyListeners();
  }

  @override
  Future<void> buyOutfit(String outfitId) async {
    buyCalls.add(outfitId);
    owned.add(outfitId);
    notifyListeners();
  }

  @override
  Future<TaskClaimResult> verifyAndToggleTask(
    DailyClassTask task,
    DateTime date,
  ) async {
    claims++;
    return claimResult;
  }
}

class _Elbee implements ElbeeGateway {
  @override
  Future<ElbeeReply> ask(
    String question, {
    required bool scheduleConsent,
  }) async => ElbeeReply(
    status: ElbeeStatus.ok,
    cards: [ElbeeCard(title: 'Horn Center', placeId: harness.horn.id)],
  );
}

GoRouter _router({String initialLocation = '/pet?from=/checklist'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/pet',
      builder: (context, state) => const PetHomeScreen(),
      routes: [
        GoRoute(
          path: 'pack',
          builder: (context, state) => const PetPackScreen(),
        ),
        GoRoute(
          path: 'shop',
          builder: (context, state) => const PetCustomizationScreen(),
        ),
        GoRoute(
          path: 'quests',
          builder: (context, state) => const PetQuestsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/checklist',
      builder: (context, state) => Scaffold(
        body: const Text('checklist page'),
        bottomNavigationBar: const NaviBottomNav(active: NaviTab.menu),
      ),
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) => Scaffold(body: const Text('map page')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  _FakeAppState state, {
  GoRouter? router,
  NavigationFlowController? flow,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final config = router ?? _router();
  addTearDown(config.dispose);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider.value(value: flow ?? harness.build()),
        Provider<ElbeeGateway>.value(value: _Elbee()),
      ],
      child: MaterialApp.router(
        routerConfig: config,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Pet Home shows Elbee, progress, gems, class and Guide', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState());

    expect(find.byType(PetHomeScreen), findsOneWidget);
    expect(find.text('Elbee · Lv 2'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.bySemanticsLabel('Elbee the shark'), findsOneWidget);
    expect(find.text("Today's quests"), findsNothing);
    expect(
      find.text('CECS 491A · Vivian Engineering Center 308'),
      findsOneWidget,
    );
    expect(find.text('Guide'), findsOneWidget);
    for (final tab in ['Home', 'Pack', 'Shop', 'Quests']) {
      expect(find.byKey(ValueKey('pet-tab-$tab')), findsOneWidget);
    }
  });

  testWidgets('Elbee stands on the rug, clear of the HUD and today card', (
    tester,
  ) async {
    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(375, 667), 1.0),
      (const Size(320, 568), 2.0),
    ]) {
      await _pump(tester, _FakeAppState(), size: size, textScale: scale);
      final room = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint && '${w.painter.runtimeType}' == '_RoomPainter',
        ),
      );
      final rug = petRugRect(room.size).shift(room.topLeft);
      final mascot = tester.getRect(find.byKey(const ValueKey('pet-mascot')));
      final hudBottom = tester
          .getRect(find.byKey(const ValueKey('pet-back')))
          .bottom;
      final card = tester.getRect(find.byKey(const ValueKey('pet-today-card')));
      final reason = '$size x$scale';

      expect(rug.contains(mascot.bottomCenter), isTrue, reason: reason);
      expect(
        tester.getRect(find.text("1 mission left today. Let's go!")).top,
        greaterThan(hudBottom),
        reason: reason,
      );
      // The card must never grow up over the HUD and its back button.
      expect(card.top, greaterThan(hudBottom), reason: reason);
      // At 2x text the taller card may cover Elbee's feet; at default text
      // it must not.
      if (scale == 1) {
        expect(mascot.bottom, lessThan(card.top), reason: reason);
      }
    }
  });

  testWidgets('Home displays loading, empty and retry states', (tester) async {
    await _pump(tester, _FakeAppState(fakeClasses: const [], busy: true));
    expect(find.text('Checking your schedule...'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await _pump(tester, _FakeAppState(fakeClasses: const []));
    expect(
      find.text('Add a class to start exploring together.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add class'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);

    final failedRefresh = _FakeAppState(
      fakeClasses: const [],
      error: 'Server down',
      refreshThrows: true,
    );
    await _pump(tester, failedRefresh);
    expect(find.textContaining("Couldn't load your classes"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(failedRefresh.refreshes, 1);

    await _pump(tester, _FakeAppState(error: 'Temporary connection issue'));
    expect(find.text('CECS 491A'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(find.textContaining('Temporary connection issue'), findsOneWidget);
  });

  testWidgets('Guide opens Elbee and routes a selected place to the map', (
    tester,
  ) async {
    final flow = harness.build();
    await _pump(tester, _FakeAppState(), flow: flow);

    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.byType(ElbeeSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Where is Horn Center?');
    await tester.tap(find.text('Ask Elbee'));
    await tester.pump();
    await tester.tap(find.text('Horn Center'));
    await tester.pumpAndSettle();
    expect(find.text('map page'), findsOneWidget);
    expect(flow.destination?.id, harness.horn.id);
  });

  testWidgets('Quests owns missions, details, check-in and inline errors', (
    tester,
  ) async {
    final state = _FakeAppState(
      claimResult: TaskClaimResult.locationUnavailable,
    );
    final router = _router(initialLocation: '/pet/quests?from=/checklist');
    await _pump(tester, state, router: router);

    expect(find.text("Today's quests"), findsOneWidget);
    expect(
      find.text('Go to Vivian Engineering Center 308 for CECS 491A'),
      findsOneWidget,
    );
    expect(find.text('Reward received'), findsOneWidget);
    expect(
      find.textContaining('A campus check-in is not proof of class attendance'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Go to Vivian Engineering Center 308 for CECS 491A'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('10:00 AM'), findsWidgets);
    expect(find.text('Reward: 10 gems'), findsOneWidget);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quest-action-1-attend')));
    await tester.pumpAndSettle();
    expect(state.claims, 1);
    expect(
      find.text('Turn on location access to check in to this class.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('running online quest duration redraws each second', (
    tester,
  ) async {
    final state = _FakeAppState(onlineRunning: true);
    await _pump(tester, state, router: _router(initialLocation: '/pet/quests'));
    expect(find.textContaining('Online session: 0:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Online session: 0:02'), findsOneWidget);
  });

  testWidgets('Quests loading, error and empty states stay in the section', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeAppState(fakeClasses: const [], busy: true),
      router: _router(initialLocation: '/pet/quests'),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pump(
      tester,
      _FakeAppState(fakeClasses: const [], error: 'Server down'),
      router: _router(initialLocation: '/pet/quests'),
    );
    expect(find.textContaining("Couldn't load today's quests"), findsOneWidget);

    await _pump(
      tester,
      _FakeAppState(fakeClasses: const []),
      router: _router(initialLocation: '/pet/quests'),
    );
    expect(find.text('Add a class on Calendar to get quests'), findsOneWidget);
    await tester.tap(find.text('Open Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
  });

  testWidgets('Pack previews, resets, and equips owned outfits only', (
    tester,
  ) async {
    final state = _FakeAppState(
      owned: {'grad_cap', 'shades'},
      equipped: 'shades',
    );
    await _pump(
      tester,
      state,
      router: _router(initialLocation: '/pet/pack?from=/checklist'),
    );

    expect(find.text('Grad Cap'), findsOneWidget);
    expect(find.text('Shades'), findsWidgets);
    expect(find.text('CSULB Tee'), findsNothing);
    await tester.tap(find.text('Grad Cap'));
    await tester.pumpAndSettle();
    expect(find.text('Previewing · not saved'), findsOneWidget);
    // Only the grid card names the outfit; no label crosses the pedestal.
    expect(find.text('Grad Cap'), findsOneWidget);
    expect(find.text('Wear Grad Cap'), findsOneWidget);
    await tester.tap(find.text('Wear Grad Cap'));
    await tester.pumpAndSettle();
    expect(state.equipCalls, ['grad_cap']);
    expect(state.buyCalls, isEmpty);
  });

  testWidgets('Shop verifies purchase and leaves equip to Pack', (
    tester,
  ) async {
    final state = _FakeAppState();
    await _pump(
      tester,
      state,
      router: _router(initialLocation: '/pet/shop?from=/map'),
    );

    // The stage label sits under Elbee, not across the feet.
    expect(
      tester.getRect(find.byKey(const ValueKey('shop-stage-elbee'))).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Elbee · No outfit')).top),
    );

    await tester.tap(find.byKey(const ValueKey('shop-shades')));
    await tester.pumpAndSettle();
    expect(state.buyCalls, ['shades']);
    expect(state.equipCalls, isEmpty);
    expect(find.text('Shades added to your Pack.'), findsOneWidget);
  });

  testWidgets('Pack reports failed equip without changing inventory', (
    tester,
  ) async {
    final state = _FakeAppState(owned: {'grad_cap'}, equipThrows: true);
    await _pump(tester, state, router: _router(initialLocation: '/pet/pack'));

    await tester.tap(find.text('Grad Cap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wear Grad Cap'));
    await tester.pumpAndSettle();
    expect(state.equipCalls, ['grad_cap']);
    expect(state.buyCalls, isEmpty);
    expect(find.textContaining('Could not wear Grad Cap'), findsOneWidget);
  });

  testWidgets('Shop disables unaffordable outfits', (tester) async {
    await _pump(
      tester,
      _FakeAppState(gems: 5),
      router: _router(initialLocation: '/pet/shop'),
    );

    expect(find.text('Need 10 more gems'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('shop-shades')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Pet back returns to the main tab and nav switches sections', (
    tester,
  ) async {
    final state = _FakeAppState();
    final router = _router(initialLocation: '/pet?from=/checklist');
    await _pump(tester, state, router: router);

    await tester.tap(find.byKey(const ValueKey('pet-tab-Quests')));
    await tester.pumpAndSettle();
    expect(find.byType(PetQuestsScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to Navipet'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
  });

  testWidgets('main Pet button preserves its Calendar return path', (
    tester,
  ) async {
    final router = _router(initialLocation: '/checklist');
    await _pump(tester, _FakeAppState(), router: router);

    await tester.tap(find.byKey(const ValueKey('nav-Pet')));
    await tester.pumpAndSettle();
    expect(find.byType(PetHomeScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-tab-Quests')));
    await tester.pumpAndSettle();
    expect(find.byType(PetQuestsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
  });

  testWidgets('Pet section meets accessibility and fits small 2x screens', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeAppState());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();

    for (final location in ['/pet', '/pet/pack', '/pet/shop', '/pet/quests']) {
      await _pump(
        tester,
        _FakeAppState(owned: {'grad_cap'}),
        router: _router(initialLocation: '$location?from=/checklist'),
        size: const Size(320, 568),
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: location);
    }
  });
}
