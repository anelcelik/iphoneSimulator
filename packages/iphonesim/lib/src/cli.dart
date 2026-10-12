import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'entrypoint.dart';
import 'flutter_sdk.dart';
import 'generated/devices.g.dart';
import 'project.dart';
import 'version.dart';

/// Runs the CLI and returns the exit code.
Future<int> runCli(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'iphonesim',
    'Run Flutter apps on Linux inside an iPhone simulator window.',
  )
    ..argParser.addFlag('version', negatable: false, help: 'Print the version.')
    ..addCommand(_RunCommand())
    ..addCommand(_PrepareCommand())
    ..addCommand(_DevicesCommand())
    ..addCommand(_DoctorCommand());

  try {
    final top = runner.parse(arguments);
    if (top['version'] == true) {
      stdout.writeln('iphonesim $packageVersion');
      return 0;
    }
    return await runner.runCommand(top) ?? 0;
  } on UsageException catch (error) {
    stderr.writeln(error);
    return 64;
  } on ProjectException catch (error) {
    stderr.writeln('iphonesim: $error');
    return 1;
  }
}

/// Options shared by `run` and `prepare`.
void _addProjectOptions(ArgParser parser) {
  parser
    ..addOption('project', abbr: 'p', help: 'The Flutter project folder.', defaultsTo: '.')
    ..addOption('target', abbr: 't', help: "The app's entrypoint.", defaultsTo: 'lib/main.dart')
    ..addOption(
      'device',
      abbr: 'd',
      help: 'Device to start with (later runs remember the one you pick in the panel).',
      allowed: <String>[for (final device in deviceProfiles) device.id],
      defaultsTo: defaultDeviceId,
    )
    ..addFlag(
      'strict-plugins',
      negatable: false,
      help: 'Let calls to plugins without a Linux implementation throw MissingPluginException '
          '(default: answer them with null so the app keeps running).',
    )
    ..addFlag(
      'ios-from-start',
      negatable: false,
      help: 'Report iOS from the first line of main() instead of from runApp(). '
          'Breaks apps that set up Linux services (e.g. sqflite FFI) before runApp().',
    )
    ..addOption('screenshots', help: 'Folder for screenshots.', valueHelp: 'dir', defaultsTo: '~/Pictures/iphoneSimulator')
    ..addFlag(
      'add-linux',
      negatable: false,
      help: 'Add the Linux runner (a linux/ folder) if the project has none. Nothing else is changed.',
    );
}

class _Prepared {
  _Prepared(this.project, this.entrypoint);

  final FlutterProject project;
  final String entrypoint;
}

Future<_Prepared> _prepare(ArgResults args, {required String? flutter}) async {
  final project = FlutterProject.find(args['project'] as String);
  if (!project.hasLinuxRunner) {
    if (args['add-linux'] != true) {
      throw ProjectException(
        '${project.root} has no Linux runner (linux/ folder), which the simulator runs on.\n'
        'Run again with --add-linux to add one. It only creates linux/; '
        'your other files stay as they are.',
      );
    }
    if (flutter == null) throw ProjectException(_noFlutter);
    await _addLinuxRunner(project, flutter);
  }
  final entrypoint = writeSimulatorFiles(
    project,
    args['target'] as String,
    SimulatorOptions(
      device: args['device'] as String,
      lenientPlugins: args['strict-plugins'] != true,
      iosFromStart: args['ios-from-start'] == true,
      screenshotDir: _expandHome(args['screenshots'] as String),
    ),
  );
  return _Prepared(project, entrypoint);
}

/// Generates a Linux runner in a scratch project and copies only its linux/
/// folder over. (`flutter create .` would also add any other template file the
/// project happens to lack, such as test/widget_test.dart.)
Future<void> _addLinuxRunner(FlutterProject project, String flutter) async {
  stdout.writeln('Adding a Linux runner to ${project.root}/linux ...');
  final scratch = Directory.systemTemp.createTempSync('iphonesim_runner');
  try {
    final generated = p.join(scratch.path, project.name);
    final result = await Process.run(flutter, <String>[
      'create',
      '--platforms=linux',
      '--project-name=${project.name}',
      '--no-pub',
      generated,
    ]);
    if (result.exitCode != 0) {
      throw ProjectException('flutter create failed:\n${result.stdout}\n${result.stderr}');
    }
    _copyDirectory(Directory(p.join(generated, 'linux')), Directory(p.join(project.root, 'linux')));
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

void _copyDirectory(Directory from, Directory to) {
  for (final entity in from.listSync(recursive: true)) {
    final target = p.join(to.path, p.relative(entity.path, from: from.path));
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}

String _expandHome(String path) {
  final home = Platform.environment['HOME'];
  if (home == null) return path;
  if (path == '~') return home;
  if (path.startsWith('~/')) return p.join(home, path.substring(2));
  return path;
}

const String _noFlutter = 'Could not find the flutter command. Put it on PATH, set FLUTTER_ROOT, '
    'or pass --flutter /path/to/flutter/bin/flutter.';

class _RunCommand extends Command<int> {
  _RunCommand() {
    _addProjectOptions(argParser);
    argParser.addOption('flutter', help: 'Path to the flutter executable.', valueHelp: 'path');
  }

  @override
  String get name => 'run';

  @override
  String get description => 'Run the app in the simulator (with hot reload). '
      'Arguments after -- go to flutter run.';

  @override
  String get invocation => 'iphonesim run [options] [-- <flutter run arguments>]';

  @override
  Future<int> run() async {
    final args = argResults!;
    final flutter = findFlutter(explicit: args['flutter'] as String?);
    if (flutter == null) throw ProjectException(_noFlutter);
    final prepared = await _prepare(args, flutter: flutter);
    final extra = args.rest;
    if (extra.contains('--release') || extra.contains('--profile')) {
      stderr.writeln('iphonesim: the iOS look needs a debug build '
          '(Flutter only lets apps pretend to be another platform in debug mode).');
    }

    final relativeEntrypoint = p.relative(prepared.entrypoint, from: prepared.project.root);
    final flutterArgs = <String>['run', '-d', 'linux', '-t', relativeEntrypoint, ...extra];
    stdout.writeln('iphonesim: ${p.basename(flutter)} ${flutterArgs.join(' ')}');

    final process = await Process.start(
      flutter,
      flutterArgs,
      workingDirectory: prepared.project.root,
      mode: ProcessStartMode.inheritStdio,
    );
    // Ctrl+C reaches flutter too (same terminal); let it shut the app down
    // and report its own exit code instead of dying first.
    final sigint = ProcessSignal.sigint.watch().listen((_) {});
    try {
      return await process.exitCode;
    } finally {
      await sigint.cancel();
    }
  }
}

class _PrepareCommand extends Command<int> {
  _PrepareCommand() {
    _addProjectOptions(argParser);
    argParser.addOption('flutter', help: 'Path to the flutter executable (for --add-linux).', valueHelp: 'path');
  }

  @override
  String get name => 'prepare';

  @override
  String get description => 'Write build/iphonesim/main.dart without running it, '
      'for launching from an editor (VS Code, Android Studio).';

  @override
  Future<int> run() async {
    final args = argResults!;
    final prepared = await _prepare(args, flutter: findFlutter(explicit: args['flutter'] as String?));
    final relative = p.relative(prepared.entrypoint, from: prepared.project.root);
    stdout
      ..writeln('Wrote $relative.')
      ..writeln('Run it with: flutter run -d linux -t $relative')
      ..writeln('Run prepare again after updating iphonesim.');
    return 0;
  }
}

class _DevicesCommand extends Command<int> {
  @override
  String get name => 'devices';

  @override
  String get description => 'List the simulated devices.';

  @override
  int run() {
    for (final device in deviceProfiles) {
      final isDefault = device.id == defaultDeviceId ? '  (default)' : '';
      stdout.writeln('${device.id.padRight(20)}${device.name.padRight(22)}'
          '${device.width.round()}×${device.height.round()} pt  '
          '${device.pixelWidth}×${device.pixelHeight} px$isDefault');
    }
    return 0;
  }
}

class _DoctorCommand extends Command<int> {
  _DoctorCommand() {
    argParser
      ..addOption('project', abbr: 'p', help: 'The Flutter project folder.', defaultsTo: '.')
      ..addOption('flutter', help: 'Path to the flutter executable.', valueHelp: 'path');
  }

  @override
  String get name => 'doctor';

  @override
  String get description => 'Check that everything the simulator needs is installed.';

  @override
  Future<int> run() async {
    final args = argResults!;
    var problems = 0;
    void ok(String message) => stdout.writeln('  ✓ $message');
    void bad(String message, String fix) {
      problems++;
      stdout
        ..writeln('  ✗ $message')
        ..writeln('    → $fix');
    }

    void note(String message, String fix) => stdout
      ..writeln('  ! $message')
      ..writeln('    → $fix');

    stdout.writeln('iphonesim $packageVersion');
    final flutter = findFlutter(explicit: args['flutter'] as String?);
    if (flutter == null) {
      bad('flutter not found', _noFlutter);
    } else {
      final version = await Process.run(flutter, <String>['--version']);
      final first = '${version.stdout}'.split('\n').first.trim();
      ok('$first ($flutter)');
      final devices = await Process.run(flutter, <String>['devices', '--machine']);
      if ('${devices.stdout}'.contains('"id": "linux"') || '${devices.stdout}'.contains('"id":"linux"')) {
        ok('Linux desktop target available');
      } else {
        bad('Flutter has no Linux desktop target',
            'flutter config --enable-linux-desktop, then flutter doctor (needs clang, cmake, ninja, GTK 3 headers).');
      }
    }

    final fonts = await _fontFamilies();
    if (fonts.any((family) => family.startsWith('SF Pro'))) {
      ok('SF Pro installed (used for iOS text)');
    } else if (fonts.contains('Inter')) {
      ok('Inter installed (stands in for SF Pro)');
    } else {
      note('No San Francisco look-alike installed: iOS text will use your desktop font',
          'install Inter (Arch: pacman -S inter-font, Debian/Ubuntu: apt install fonts-inter), '
          'or SF Pro from https://developer.apple.com/fonts/');
    }

    try {
      final project = FlutterProject.find(args['project'] as String);
      if (project.hasLinuxRunner) {
        ok('Project ${project.name} has a Linux runner');
      } else {
        note('Project ${project.name} has no linux/ folder', 'iphonesim run --add-linux');
      }
    } on ProjectException {
      stdout.writeln('  - Not inside a Flutter project (project checks skipped)');
    }
    return problems == 0 ? 0 : 1;
  }

  static Future<Set<String>> _fontFamilies() async {
    try {
      final result = await Process.run('fc-list', <String>[r'--format=%{family}\n']);
      return <String>{
        for (final line in '${result.stdout}'.split('\n'))
          for (final family in line.split(',')) family.trim(),
      };
    } on ProcessException {
      return <String>{};
    }
  }
}
