import 'dart:io';

import 'package:flutter/services.dart';

/// Font families Flutter asks for when the platform is iOS. On an iPhone the
/// engine maps them to San Francisco; on Linux they don't exist, so text falls
/// back to the desktop default (usually Liberation Sans or DejaVu).
const String iosTextFamily = 'CupertinoSystemText';
const String iosDisplayFamily = 'CupertinoSystemDisplay';

/// Stand-ins for San Francisco, best first, as (label, text families,
/// display families) in fontconfig terms.
///
/// SF Pro is a free download from developer.apple.com/fonts. Its license
/// covers mock-ups of iOS apps, but not redistribution, so this project never
/// ships it: it is used only when you installed it yourself. Inter was drawn
/// after it and is open source (`pacman -S inter-font`, `apt install fonts-inter`).
const List<(String, List<String>, List<String>)> _candidates =
    <(String, List<String>, List<String>)>[
  ('SF Pro', <String>['SF Pro Text', 'SF Pro'], <String>['SF Pro Display', 'SF Pro']),
  ('Inter', <String>['Inter'], <String>['Inter Display', 'Inter']),
];

/// Registers the best installed stand-in under the iOS family names.
///
/// Returns its label, or null when none is installed.
Future<String?> loadIosFonts() async {
  final Map<String, List<String>> files = await _installedFonts();
  for (final (String label, List<String> textFamilies, List<String> displayFamilies)
      in _candidates) {
    final List<String> text = _firstMatch(files, textFamilies);
    if (text.isEmpty) continue;
    final List<String> display = _firstMatch(files, displayFamilies);
    await _register(iosTextFamily, text);
    await _register(iosDisplayFamily, display.isEmpty ? text : display);
    return label;
  }
  return null;
}

List<String> _firstMatch(Map<String, List<String>> files, List<String> families) {
  for (final String family in families) {
    final List<String>? found = files[family];
    if (found != null && found.isNotEmpty) return found;
  }
  return const <String>[];
}

Future<void> _register(String family, List<String> paths) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in paths) {
    loader.addFont(File(path).readAsBytes().then((Uint8List bytes) => ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Font files by family name, from fontconfig. Static files win over variable
/// ones, because Flutter doesn't map FontWeight onto a variable font's axis.
Future<Map<String, List<String>>> _installedFonts() async {
  final ProcessResult result;
  try {
    result = await Process.run('fc-list', <String>[r'--format=%{family}|%{file}\n']);
  } on ProcessException {
    return const <String, List<String>>{};
  }
  if (result.exitCode != 0) return const <String, List<String>>{};

  final Map<String, List<String>> statics = <String, List<String>>{};
  final Map<String, List<String>> variables = <String, List<String>>{};
  for (final String line in '${result.stdout}'.split('\n')) {
    final int bar = line.lastIndexOf('|');
    if (bar <= 0) continue;
    final String file = line.substring(bar + 1);
    final String lower = file.toLowerCase();
    if (!lower.endsWith('.otf') && !lower.endsWith('.ttf')) continue;
    final bool variable = lower.contains('variable') || file.contains('[');
    for (final String family in line.substring(0, bar).split(',')) {
      (variable ? variables : statics).putIfAbsent(family.trim(), () => <String>[]).add(file);
    }
  }
  for (final MapEntry<String, List<String>> entry in variables.entries) {
    statics.putIfAbsent(entry.key, () => entry.value);
  }
  return statics;
}
