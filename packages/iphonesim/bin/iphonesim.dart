import 'dart:io';

import 'package:iphonesim/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
