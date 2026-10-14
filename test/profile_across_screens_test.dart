import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/user_account.dart';
import 'package:navipet/screens/checklist_screen.dart';
import 'package:navipet/screens/map_screen.dart';
import 'package:navipet/widgets/profile_avatar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow_fakes.dart' as harness;

class _ProfileState extends AppState {
  _ProfileState(this.user);
  final UserAccount user;

  @override
  UserAccount? get activeUser => user;

  @override
  void reportAvatarLoadFailed(String url) {}
}

void main() {
  testWidgets('map and calendar use the same saved profile avatar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const user = UserAccount(
      id: 'user',
      name: 'Alex',
      email: 'alex@example.com',
      avatarColor: Colors.blue,
      avatarUrl: 'https://example.com/avatar.png',
      gems: 0,
      level: 1,
    );
    final state = _ProfileState(user);
    final controller = harness.build();
    Future<ProfileAvatar> show(Widget screen) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider.value(value: controller),
          ],
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
      return tester.widget<ProfileAvatar>(find.byType(ProfileAvatar).first);
    }

    final calendar = await show(const ChecklistScreen());
    final map = await show(MapScreen(controller: controller));
    expect(calendar.name, user.name);
    expect(calendar.color, user.avatarColor);
    expect(calendar.imageUrl, user.avatarUrl);
    expect(map.name, calendar.name);
    expect(map.color, calendar.color);
    expect(map.imageUrl, calendar.imageUrl);
  });

  testWidgets('both account entry points use the initial without a photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const user = UserAccount(
      id: 'user',
      name: 'Alex',
      email: 'alex@example.com',
      avatarColor: Colors.blue,
      gems: 0,
      level: 1,
    );
    final state = _ProfileState(user);
    final controller = harness.build();
    for (final screen in [
      const ChecklistScreen(),
      MapScreen(controller: controller),
    ]) {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider.value(value: controller),
          ],
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    }
  });
}
