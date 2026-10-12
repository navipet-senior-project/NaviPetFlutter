import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navipet/data/app_state.dart';
import 'package:navipet/data/profile_gateway.dart';
import 'package:navipet/screens/account_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeProfileGateway implements ProfileGateway {
  final List<(List<int>, String)> uploads = [];

  @override
  Future<RemoteProfile> fetchProfile() async =>
      const RemoteProfile(displayName: 'Jane');

  @override
  Future<AvatarUpload> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    uploads.add((bytes, filename));
    return const AvatarUpload(
      uploadId: 'upload-1',
      avatarUrl: 'https://cdn.test/pending.png',
    );
  }

  @override
  Future<RemoteProfile> updateProfile({
    String? displayName,
    String? avatarUploadId,
    String? role,
  }) => throw UnimplementedError();

  @override
  Future<void> discardAvatarUpload(String uploadId) async {}
}

/// An offline Supabase client with a restored session: a non-JWT access
/// token has no expiry, so nothing refreshes and nothing hits the network.
Future<SupabaseClient> _signedIn({required bool anonymous}) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    // Every table read (profile, classes, task completions) comes back empty.
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'test-token',
      'token_type': 'bearer',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'email': 'jane@student.csulb.edu',
        'created_at': '',
        'is_anonymous': anonymous,
      },
    }),
  );
  return client;
}

/// Pumps [screen] and runs [body]. The settings cards put ListTiles inside a
/// coloured Container, which trips Flutter's debug-only "ink splashes may be
/// invisible" report (existing code, unrelated to the avatar); only that
/// report is ignored.
Future<void> _run(
  WidgetTester tester,
  AppState state,
  Widget screen,
  void Function() body,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('ink splashes may be invisible')) {
      return;
    }
    original?.call(details);
  };
  try {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
    body();
  } finally {
    FlutterError.onError = original;
    state.dispose();
  }
}

/// Alternates real time (for image decode/encode in the engine) with pumps
/// (for the continuations queued in the test's fake-async zone).
Future<void> _settleUntil(
  WidgetTester tester,
  String what,
  bool Function() done,
) async {
  for (var i = 0; i < 150 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'timed out waiting for $what');
}

void main() {
  final pencil = find.byTooltip('Change profile photo');

  testWidgets('Edit Profile requires Student or Professor role', (
    tester,
  ) async {
    final state = AppState(
      supabase: await _signedIn(anonymous: false),
      profileGateway: _FakeProfileGateway(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(dropdown.items!.map((item) => item.value).toList(), [
      'student',
      'professor',
    ]);
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(
      find.text('Choose a role before saving your profile.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('Edit Profile: pencil, pick, crop and upload a PNG', (
    tester,
  ) async {
    final png = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 30, 20),
        Paint()..color = const Color(0xFF00AA00),
      );
      final image = await recorder.endRecording().toImage(30, 20);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    final gateway = _FakeProfileGateway();
    final state = AppState(
      supabase: await _signedIn(anonymous: false),
      profileGateway: gateway,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: EditProfileScreen(
            pickImage: () async => XFile.fromData(png, name: 'photo.heic'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(pencil);
    await _settleUntil(
      tester,
      'the crop screen',
      () => find.text('Done').evaluate().isNotEmpty,
    );
    expect(find.text('Drag and pinch to position your photo'), findsOneWidget);
    await tester.pumpAndSettle(); // Let the route finish sliding in.

    await tester.tap(find.text('Done'));
    await _settleUntil(tester, 'the upload', () => gateway.uploads.isNotEmpty);

    final (bytes, filename) = gateway.uploads.single;
    expect(filename, 'avatar.png');
    expect(Uint8List.fromList(bytes.sublist(0, 8)), [
      137, 80, 78, 71, 13, 10, 26, 10, // PNG signature
    ]);
    // Leaving the screen unsaved discards the pending upload; unmount it
    // before disposing the state it listens to.
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  for (final (label, screen) in [
    ('Profile & Settings', const AccountSettingsScreen()),
    ('Edit Profile', const EditProfileScreen()),
  ]) {
    group(label, () {
      testWidgets('shows the pencil for a signed-in account', (tester) async {
        final client = await _signedIn(anonymous: false);
        final state = AppState(
          supabase: client,
          profileGateway: _FakeProfileGateway(),
        );
        await _run(tester, state, screen, () {
          expect(state.canEditAvatar, isTrue);
          expect(pencil, findsOneWidget);
          expect(
            find.descendant(of: pencil, matching: find.byIcon(Icons.edit)),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
        });
      });

      testWidgets('hides the pencil for a guest', (tester) async {
        final client = await _signedIn(anonymous: true);
        final state = AppState(
          supabase: client,
          profileGateway: _FakeProfileGateway(),
        );
        await _run(tester, state, screen, () {
          expect(state.activeUser?.isAnonymous, isTrue);
          expect(pencil, findsNothing);
        });
      });

      testWidgets('hides the pencil without a backend', (tester) async {
        final client = await _signedIn(anonymous: false);
        final state = AppState(supabase: client);
        await _run(tester, state, screen, () {
          expect(state.activeUser, isNotNull);
          expect(pencil, findsNothing);
        });
      });
    });
  }
}
