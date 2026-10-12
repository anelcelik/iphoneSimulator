import 'dart:io';

import 'package:iphonesim/src/bundle.dart';
import 'package:iphonesim/src/entrypoint.dart';
import 'package:iphonesim/src/flutter_sdk.dart';
import 'package:iphonesim/src/project.dart';
import 'package:iphonesim/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory _app(String pubspec, {bool linux = true}) {
  final dir = Directory.systemTemp.createTempSync('iphonesim_cli');
  addTearDown(() => dir.deleteSync(recursive: true));
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
  File(p.join(dir.path, 'lib', 'main.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync('void main() {}\n');
  if (linux) {
    File(p.join(dir.path, 'linux', 'CMakeLists.txt')).createSync(recursive: true);
  }
  return dir;
}

const String _flutterPubspec = '''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''';

void main() {
  test('the embedded shell matches packages/iphonesim_shell', () {
    final shellLib = Directory('../iphonesim_shell/lib');
    expect(File(bundleOutputPath).readAsStringSync(), renderBundle(shellLib),
        reason: 'Run: dart run tool/bundle_shell.dart');
    expect(File(devicesOutputPath).readAsStringSync(), renderDevices(shellLib),
        reason: 'Run: dart run tool/bundle_shell.dart');
  });

  test('version.dart matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('\nversion: $packageVersion\n'));
  });

  test('finds the project from a subfolder and imports lib/ targets by package', () {
    final dir = _app(_flutterPubspec);
    final project = FlutterProject.find(p.join(dir.path, 'lib'));
    expect(project.name, 'my_app');
    expect(project.importFor('lib/main.dart'), 'package:my_app/main.dart');
  });

  test('targets outside lib/ are imported relative to build/iphonesim', () {
    final dir = _app(_flutterPubspec);
    File(p.join(dir.path, 'tool', 'demo.dart')).createSync(recursive: true);
    expect(FlutterProject.find(dir.path).importFor('tool/demo.dart'), '../../tool/demo.dart');
  });

  test('rejects plain Dart packages', () {
    final dir = _app('name: not_flutter\n');
    expect(() => FlutterProject.find(dir.path), throwsA(isA<ProjectException>()));
  });

  test('writes the shell and an entrypoint under build/iphonesim only', () {
    final dir = _app(_flutterPubspec);
    final project = FlutterProject.find(dir.path);
    final entry = writeSimulatorFiles(
      project,
      'lib/main.dart',
      const SimulatorOptions(device: 'iphone-se', lenientPlugins: false, screenshotDir: r'/tmp/sh$ots "x"'),
    );
    expect(entry, p.join(dir.path, 'build', 'iphonesim', 'main.dart'));
    final source = File(entry).readAsStringSync();
    expect(source, contains("import \"package:my_app/main.dart\" as app;"));
    expect(source, contains('device: "iphone-se"'));
    expect(source, contains('lenientPlugins: false'));
    expect(source, contains(r'screenshotDir: "/tmp/sh\$ots \"x\""'));
    final shellEntry = File(p.join(dir.path, 'build', 'iphonesim', 'shell', 'iphonesim_shell.dart'));
    expect(shellEntry.readAsStringSync(), startsWith(copiedFileHeader));
    expect(File(p.join(dir.path, 'build', 'iphonesim', 'shell', 'src', 'binding.dart')).existsSync(), isTrue);
  });

  test('finds flutter on PATH, then in ~/development', () {
    final home = Directory.systemTemp.createTempSync('iphonesim_home');
    addTearDown(() => home.deleteSync(recursive: true));
    final dev = File(p.join(home.path, 'development', 'flutter', 'bin', 'flutter'))..createSync(recursive: true);
    expect(findFlutter(environment: <String, String>{'HOME': home.path, 'PATH': '/nonexistent'}), dev.path);
    final onPath = File(p.join(home.path, 'bin', 'flutter'))..createSync(recursive: true);
    expect(
      findFlutter(environment: <String, String>{'HOME': home.path, 'PATH': p.join(home.path, 'bin')}),
      onPath.path,
    );
  });
}
