import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds the `flutter` executable: --flutter, then $FLUTTER_ROOT, then PATH,
/// then the usual install folders (the Flutter docs suggest ~/development).
String? findFlutter({String? explicit, Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  if (explicit != null) return File(explicit).existsSync() ? explicit : null;

  final candidates = <String>[
    if (env['FLUTTER_ROOT'] case final root?) p.join(root, 'bin', 'flutter'),
    for (final dir in (env['PATH'] ?? '').split(':'))
      if (dir.isNotEmpty) p.join(dir, 'flutter'),
    if (env['HOME'] case final home?) ...<String>[
      p.join(home, 'development', 'flutter', 'bin', 'flutter'),
      p.join(home, 'flutter', 'bin', 'flutter'),
      p.join(home, 'fvm', 'default', 'bin', 'flutter'),
      p.join(home, 'snap', 'flutter', 'common', 'flutter', 'bin', 'flutter'),
    ],
    '/opt/flutter/bin/flutter',
    '/usr/lib/flutter/bin/flutter',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}
