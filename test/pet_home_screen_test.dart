import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/course_class.dart';
import 'package:navipet/data/elbee_gateway.dart';
import 'package:navipet/data/elbee_reply.dart';
import 'package:navipet/data/navigation_flow_controller.dart';
import 'package:navipet/data/user_account.dart';
import 'package:navipet/router/app_router.dart';
import 'package:navipet/screens/checklist_screen.dart';
import 'package:navipet/screens/pet_customization_screen.dart';
import 'package:navipet/screens/pet_home_screen.dart';
import 'package:navipet/widgets/class_detail_sheet.dart';
import 'package:navipet/widgets/elbee_sheet.dart';
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

/// An [AppState] with no backend: every read is canned and every write that
/// would reach Supabase is recorded instead.
class _FakeAppState extends AppState {
  _FakeAppState({
    this.fakeClasses = const [_inPerson, _online],
    this.busy = false,
    this.error,
    this.owned = const {},
    this.equipped,
    this.refreshThrows = false,
    this.equipThrows = false,
  });

  final List<CourseClass> fakeClasses;
  final bool busy;
  final String? error;
  final Set<String> owned;
  String? equipped;
  final bool refreshThrows;
  final bool equipThrows;

  int refreshes = 0;
  final equipCalls = <String>[];
  final buyCalls = <String>[];
  int claims = 0;

  @override
  bool get isAuthenticated => true;

  // A dark avatar: the default amber one fails the contrast guideline on
  // every screen, which is not what these tests are about.
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
  List<CourseClass> get classes => fakeClasses;

  @override
  bool get classesBusy => busy;

  @override
  String? get classesError => error;

  @override
  int get points => 120;

  @override
  Set<String> get ownedOutfits => owned;

  @override
  String? get equippedOutfit => equipped;

  // Seven verified completions: level 2, two of five toward level 3.
  @override
  int completionCountFor(String classId) => classId == '1' ? 7 : 0;

  @override
  List<DailyClassTask> dailyTasks([DateTime? day]) => [
    for (final course in fakeClasses)
      DailyClassTask(
        course: course,
        kind: course.isOnline ? 'attend_online' : 'attend',
        label: course.isOnline
            ? 'Attend ${course.courseCode} online'
            : 'Go to ${course.locationLabel} for ${course.courseCode}',
        reward: course.isOnline ? 5 : 10,
        done: course.isOnline,
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
  Future<void> buyOutfit(String outfitId) async => buyCalls.add(outfitId);

  @override
  Future<TaskClaimResult> verifyAndToggleTask(
    DailyClassTask task,
    DateTime date,
  ) async {
    claims++;
    return TaskClaimResult.claimed;
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

/// Pet Home on its real path, with the screens it links to stubbed out.
GoRouter _stubRouter() => GoRouter(
  initialLocation: '/pet',
  routes: [
    GoRoute(
      path: '/pet',
      builder: (context, state) => const PetHomeScreen(),
      routes: [
        GoRoute(
          path: 'shop',
          builder: (context, state) => const Scaffold(body: Text('shop page')),
        ),
      ],
    ),
    for (final page in ['checklist', 'map', 'account'])
      GoRoute(
        path: '/$page',
        builder: (context, state) => Scaffold(body: Text('$page page')),
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
  final config = router ?? _stubRouter();
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

String _sharkAsset(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byType(PetHomeScreen),
      matching: find.byType(Image),
    ),
  );
  return (image.image as AssetImage).assetName;
}

void main() {
  testWidgets('shows the shark, level, gems, actions, message and the day', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState());

    expect(_sharkAsset(tester), 'assets/images/elbee.png');
    expect(find.text('Level 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Level 2, 2 of 5 verified missions to the next level',
      ),
      findsOneWidget,
    );
    expect(find.text('120'), findsOneWidget);
    expect(find.bySemanticsLabel('120 gems'), findsOneWidget);
    for (final action in ['Quest', 'Shop', 'Pack', 'Guide']) {
      expect(find.text(action), findsOneWidget);
    }
    expect(find.text("1 mission left today. Let's go!"), findsOneWidget);

    expect(find.text("Today's missions"), findsOneWidget);
    expect(
      find.text('Go to Vivian Engineering Center 308 for CECS 491A'),
      findsOneWidget,
    );
    expect(find.text('CECS 491A · 10:00–11:15 AM'), findsOneWidget);
    expect(find.text('Completed · CECS 453 · 1:00–2:15 PM'), findsOneWidget);
    expect(find.text('Upcoming classes'), findsOneWidget);
    expect(find.text('CECS 491A · Senior Project'), findsOneWidget);
    expect(find.text('CECS 453 · Mobile Apps'), findsOneWidget);
  });

  testWidgets('the equipped outfit picks the shark artwork', (tester) async {
    await _pump(
      tester,
      _FakeAppState(owned: {'grad_cap'}, equipped: 'grad_cap'),
    );
    expect(_sharkAsset(tester), 'assets/images/elbee_graduate.png');
    expect(
      find.bySemanticsLabel('Elbee the shark, wearing Grad Cap'),
      findsOneWidget,
    );
  });

  testWidgets('an outfit without artwork shows as a badge on the shark', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState(owned: {'shades'}, equipped: 'shades'));
    expect(_sharkAsset(tester), 'assets/images/elbee.png');
    expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
  });

  testWidgets('loading shows progress instead of an empty day or zero gems', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState(fakeClasses: const [], busy: true));

    expect(find.text('Loading your day...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Gems loading'), findsOneWidget);
    expect(find.text('Checking your schedule...'), findsOneWidget);
    expect(find.text('No classes yet'), findsNothing);
  });

  testWidgets('no classes offers the Calendar', (tester) async {
    await _pump(tester, _FakeAppState(fakeClasses: const []));

    expect(find.text('No classes yet'), findsOneWidget);
    expect(find.text("Add a class and I'll plan our day!"), findsOneWidget);
    expect(find.text("Today's missions"), findsNothing);

    await tester.tap(find.text('Open Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
  });

  testWidgets('a failed load says so, hides the empty state and retries', (
    tester,
  ) async {
    final state = _FakeAppState(fakeClasses: const [], error: 'Server down');
    await _pump(tester, state);

    expect(
      find.text("Couldn't load your classes. Server down"),
      findsOneWidget,
    );
    expect(find.text('No classes yet'), findsNothing);
    expect(find.textContaining("couldn't load your day"), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(state.refreshes, 1);
  });

  testWidgets('a refresh that throws keeps the day and shows the error', (
    tester,
  ) async {
    final state = _FakeAppState(refreshThrows: true);
    await _pump(tester, state);
    expect(find.text('Retry'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(state.refreshes, 1);
    expect(find.textContaining('Could not reach NaviPet'), findsOneWidget);
    expect(find.text("Today's missions"), findsOneWidget);
  });

  testWidgets('a mission opens its details without claiming anything', (
    tester,
  ) async {
    final state = _FakeAppState();
    await _pump(tester, state);

    await tester.tap(
      find.text('Go to Vivian Engineering Center 308 for CECS 491A'),
    );
    await tester.pumpAndSettle();

    expect(find.text('CECS 491A · Senior Project'), findsWidgets);
    expect(find.text('10:00–11:15 AM'), findsOneWidget);
    expect(find.text('Vivian Engineering Center 308'), findsOneWidget);
    expect(
      find.text('10 gems, added once NaviPet verifies the mission'),
      findsOneWidget,
    );
    expect(find.text('Not completed yet'), findsOneWidget);
    expect(
      find.textContaining('It is not proof of class attendance.'),
      findsOneWidget,
    );
    expect(state.claims, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Open Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
    expect(state.claims, 0);
  });

  testWidgets('an online mission shows its status and no check-in note', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState());

    await tester.tap(find.text('Attend CECS 453 online'));
    await tester.pumpAndSettle();

    expect(find.text('Completed today'), findsOneWidget);
    expect(find.text('Online class'), findsOneWidget);
    expect(find.textContaining('not proof of class attendance'), findsNothing);
  });

  testWidgets('an upcoming class opens the class details', (tester) async {
    await _pump(tester, _FakeAppState());

    await tester.ensureVisible(find.text('CECS 453 · Mobile Apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CECS 453 · Mobile Apps'));
    await tester.pumpAndSettle();

    expect(find.byType(ClassDetailSheet), findsOneWidget);
    expect(find.text('Edit class'), findsOneWidget);
  });

  testWidgets('Quest opens the Calendar and Shop opens the store', (
    tester,
  ) async {
    await _pump(tester, _FakeAppState());

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.text('shop page'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PetHomeScreen), findsOneWidget);

    await tester.tap(find.text('Quest'));
    await tester.pumpAndSettle();
    expect(find.text('checklist page'), findsOneWidget);
  });

  testWidgets('an empty Pack leads to the Shop', (tester) async {
    await _pump(tester, _FakeAppState());

    await tester.tap(find.text('Pack'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your pack is empty'), findsOneWidget);

    await tester.tap(find.text('Open Shop'));
    await tester.pumpAndSettle();
    expect(find.text('shop page'), findsOneWidget);
  });

  testWidgets('Pack wears an owned outfit and never buys one', (tester) async {
    final state = _FakeAppState(
      owned: {'grad_cap', 'shades'},
      equipped: 'shades',
    );
    await _pump(tester, state);

    await tester.tap(find.text('Pack'));
    await tester.pumpAndSettle();
    expect(find.text('Grad Cap'), findsOneWidget);
    expect(find.text('Shades'), findsOneWidget);
    expect(find.text('Wearing'), findsOneWidget);
    // Unowned outfits are not offered.
    expect(find.text('CSULB Tee'), findsNothing);
    expect(find.text('Beach Hat'), findsNothing);

    await tester.tap(find.text('Wear'));
    await tester.pumpAndSettle();

    expect(state.equipCalls, ['grad_cap']);
    expect(state.buyCalls, isEmpty);
    expect(_sharkAsset(tester), 'assets/images/elbee_graduate.png');
  });

  testWidgets('a failed equip is reported and changes nothing', (tester) async {
    final state = _FakeAppState(owned: {'grad_cap'}, equipThrows: true);
    await _pump(tester, state);

    await tester.tap(find.text('Pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wear'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not wear Grad Cap'), findsOneWidget);
    expect(_sharkAsset(tester), 'assets/images/elbee.png');
  });

  testWidgets('Guide asks Elbee and opens a verified place on the map', (
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

  testWidgets('meets the tap target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeAppState());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    for (final action in ['Quest', 'Shop', 'Pack', 'Guide']) {
      expect(
        tester.getSemantics(find.byKey(ValueKey('pet-action-$action'))),
        matchesSemantics(
          label: action,
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    }
    handle.dispose();
  });

  for (final state in [
    () => _FakeAppState(owned: {'shades'}, equipped: 'shades'),
    () => _FakeAppState(fakeClasses: const [], error: 'Server down'),
    () => _FakeAppState(fakeClasses: const []),
  ]) {
    testWidgets('fits a small phone at 2x text without overflow', (
      tester,
    ) async {
      await _pump(tester, state(), size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);

      // The room scrolls with the page, so Pack can start below the fold.
      await tester.ensureVisible(find.text('Pack'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pack'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the app router serves Pet Home at /pet and the store under it', (
    tester,
  ) async {
    // No classes: the Calendar's task list is not what this test is about.
    final state = _FakeAppState(fakeClasses: const []);
    await _pump(
      tester,
      state,
      router: createAppRouter(state, initialLocation: '/pet'),
    );
    expect(find.byType(PetHomeScreen), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.byType(PetCustomizationScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PetCustomizationScreen), findsNothing);
    expect(find.byType(PetHomeScreen), findsOneWidget);

    await tester.tap(find.text('Quest'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChecklistScreen), findsOneWidget);
  });
}
