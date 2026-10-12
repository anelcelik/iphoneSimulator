import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'controller.dart';
import 'fonts.dart';
import 'messenger.dart';
import 'shell.dart';

/// A [WidgetsFlutterBinding] that puts the app inside the simulator.
///
/// It must exist before the app's own `main()` runs, so that the app's
/// `WidgetsFlutterBinding.ensureInitialized()` and `runApp()` get this one.
class SimulatorBinding extends WidgetsFlutterBinding {
  SimulatorBinding._(this.controller);

  /// Fields are initialized before the base constructor runs
  /// `initInstances()`, which is what calls [createBinaryMessenger].
  final SimulatorController controller;

  static SimulatorBinding? _instance;

  static SimulatorBinding get instance => _instance!;

  static SimulatorBinding ensureInitialized(SimulatorConfig config) {
    final SimulatorBinding? existing = _instance;
    if (existing != null) return existing;
    bool bindingExists;
    try {
      WidgetsBinding.instance;
      bindingExists = true;
    } catch (_) {
      bindingExists = false;
    }
    if (bindingExists) {
      throw StateError(
        'iphonesim: a Flutter binding already exists, so the simulator cannot install its own. '
        "Something initialized Flutter before the app's main() ran.",
      );
    }
    return _instance = SimulatorBinding._(SimulatorController(config));
  }

  @override
  BinaryMessenger createBinaryMessenger() => SimulatorMessenger(
        super.createBinaryMessenger(),
        controller,
        lenient: controller.config.lenientPlugins,
      );

  @override
  void handlePointerEvent(PointerEvent event) {
    final PointerEvent? transformed = controller.touch.transform(event);
    if (transformed != null) super.handlePointerEvent(transformed);
  }

  @override
  void handleViewFocusChanged(ViewFocusEvent event) {
    // The foreground app on an iPhone never loses focus. Flutter on the
    // desktop parks focus when the window is deactivated, which would close
    // the keyboard and unfocus text fields every time you switch to your
    // editor to change code.
    if (event.state == ViewFocusState.unfocused) return;
    super.handleViewFocusChanged(event);
  }

  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    // Code before runApp() saw the real platform, so desktop set-up (such as
    // sqflite's FFI factory) took its Linux path. From here on, the UI is iOS.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    return super.wrapWithDefaultView(SimulatorShell(controller: controller, app: rootWidget));
  }
}

/// Runs [appMain], the app's own `main` function, inside the simulator.
///
/// Called from the entrypoint `iphonesim run` generates.
void runSimulated(Function appMain, SimulatorConfig config) {
  if (!kDebugMode) {
    // debugDefaultTargetPlatformOverride only exists in debug builds.
    debugPrint('[iphonesim] Profile and release builds keep the Linux look; use a debug build.');
  }
  final SimulatorBinding binding = SimulatorBinding.ensureInitialized(config);
  if (config.iosFromStart) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  unawaited(loadIosFonts().then(binding.controller.setFonts, onError: (Object error) {
    debugPrint('[iphonesim] Could not load fonts: $error');
    binding.controller.setFonts(null);
  }));

  if (appMain is Function()) {
    appMain();
  } else if (appMain is Function(List<String>)) {
    appMain(<String>[]);
  } else {
    throw ArgumentError('iphonesim: unsupported main() signature: ${appMain.runtimeType}');
  }
}
