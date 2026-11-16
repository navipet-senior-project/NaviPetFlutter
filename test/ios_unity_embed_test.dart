@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _framework = 'UnityFramework.framework';
const _metadata = '$_framework/Data/Managed/Metadata/global-metadata.dat';

/// The Runner's "Embed Unity AR" build phase script, as Xcode runs it.
String _embedScript() {
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final literal = RegExp(
    r'name = "Embed Unity AR";[\s\S]*?shellScript = ("(?:[^"\\]|\\.)*");',
  ).firstMatch(project)!.group(1)!;
  // The pbxproj escapes used here (\n, \", \\) are also JSON string escapes.
  return jsonDecode(literal) as String;
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('unity_embed_test'));
  tearDown(() => root.deleteSync(recursive: true));

  void stage(String path) =>
      File('${root.path}/ios/unity-ar/$path').createSync(recursive: true);

  Future<ProcessResult> embed() => Process.run(
    '/bin/sh',
    ['-c', _embedScript()],
    environment: {
      'PROJECT_DIR': '${root.path}/ios',
      'TARGET_BUILD_DIR': '${root.path}/build',
      'FRAMEWORKS_FOLDER_PATH': 'Runner.app/Frameworks',
      'EXPANDED_CODE_SIGN_IDENTITY': '',
    },
  );

  File embedded(String path) =>
      File('${root.path}/build/Runner.app/Frameworks/$path');

  test('embeds the Unity data payload inside the app framework', () async {
    stage('$_framework/UnityFramework');
    stage(_metadata);
    File('${root.path}/ios/unity-ar/$_metadata').writeAsStringSync('metadata');

    final result = await embed();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(embedded(_metadata).readAsStringSync(), 'metadata');
  });

  test('fails the build when the framework has no IL2CPP metadata', () async {
    stage('$_framework/UnityFramework');

    final result = await embed();

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('error: '));
    expect(
      result.stderr,
      contains('Data/Managed/Metadata/global-metadata.dat'),
    );
  });

  test('builds without Unity when no framework is staged', () async {
    final result = await embed();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(embedded(_framework).existsSync(), isFalse);
  });
}
