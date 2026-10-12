// Embeds the shell's sources into the CLI, so a compiled `iphonesim` binary
// is self-contained. Run after changing packages/iphonesim_shell/lib:
//
//   dart run tool/bundle_shell.dart
import 'dart:io';

import 'package:iphonesim/src/bundle.dart';

void main() {
  final shellLib = Directory('../iphonesim_shell/lib');
  if (!shellLib.existsSync()) {
    stderr.writeln('Run this from packages/iphonesim (shell sources not found).');
    exit(1);
  }
  File(bundleOutputPath).writeAsStringSync(renderBundle(shellLib));
  File(devicesOutputPath).writeAsStringSync(renderDevices(shellLib));
  stdout.writeln('Wrote $bundleOutputPath and $devicesOutputPath.');
}
