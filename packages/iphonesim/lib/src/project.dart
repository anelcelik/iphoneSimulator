import 'dart:io';

import 'package:path/path.dart' as p;

class ProjectException implements Exception {
  ProjectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The Flutter app being simulated.
class FlutterProject {
  FlutterProject._(this.root, this.name);

  /// Finds the project containing [start] (the nearest pubspec.yaml upwards).
  factory FlutterProject.find(String start) {
    var dir = Directory(p.absolute(start));
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) return FlutterProject._fromPubspec(dir.path, pubspec.readAsStringSync());
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw ProjectException('No pubspec.yaml in $start or any folder above it. '
            'Run iphonesim inside a Flutter project, or pass --project.');
      }
      dir = parent;
    }
  }

  factory FlutterProject._fromPubspec(String root, String pubspec) {
    final name = RegExp(r'^name:\s*([A-Za-z_][A-Za-z0-9_]*)', multiLine: true).firstMatch(pubspec)?.group(1);
    if (name == null) throw ProjectException('$root/pubspec.yaml has no valid name.');
    if (!RegExp(r'^\s+sdk:\s*flutter\s*$', multiLine: true).hasMatch(pubspec)) {
      throw ProjectException('$root is a Dart package, not a Flutter app (no flutter SDK dependency).');
    }
    return FlutterProject._(p.normalize(root), name);
  }

  final String root;

  /// The package name from pubspec.yaml.
  final String name;

  String get buildDir => p.join(root, 'build', 'iphonesim');

  bool get hasLinuxRunner => File(p.join(root, 'linux', 'CMakeLists.txt')).existsSync();

  /// How the generated entrypoint (in build/iphonesim/) imports [target].
  String importFor(String target) {
    final absolute = p.normalize(p.absolute(root, target));
    if (!File(absolute).existsSync()) throw ProjectException('Target $target does not exist.');
    final lib = p.join(root, 'lib');
    if (p.isWithin(lib, absolute)) {
      return 'package:$name/${p.posix.joinAll(p.split(p.relative(absolute, from: lib)))}';
    }
    return p.posix.joinAll(p.split(p.relative(absolute, from: buildDir)));
  }
}
