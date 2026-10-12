import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'device_frame.dart';
import 'devices.dart';
import 'keyboard.dart';
import 'panel.dart';
import 'status_bar.dart';

/// The simulator window: the app inside a phone, and the control panel.
///
/// The app widget is kept under one [GlobalKey], so switching device,
/// orientation or appearance re-lays it out without losing its state.
class SimulatorShell extends StatefulWidget {
  const SimulatorShell({super.key, required this.controller, required this.app});

  final SimulatorController controller;
  final Widget app;

  @override
  State<SimulatorShell> createState() => _SimulatorShellState();
}

class _SimulatorShellState extends State<SimulatorShell> {
  final GlobalKey _windowKey = GlobalKey(debugLabel: 'iphonesim window');
  final GlobalKey _screenKey = GlobalKey(debugLabel: 'iphonesim screen');
  final GlobalKey _screenshotKey = GlobalKey(debugLabel: 'iphonesim screenshot');
  final GlobalKey _probeKey = GlobalKey(debugLabel: 'iphonesim status style');
  final GlobalKey _appKey = GlobalKey(debugLabel: 'iphonesim app');

  SimulatorController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.screenshotter = _saveScreenshot;
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
    final String? selfTest = Platform.environment['IPHONESIM_SELFTEST_SHOT'];
    if (selfTest != null && selfTest.isNotEmpty) unawaited(_selfTest(selfTest));
  }

  @override
  void didUpdateWidget(SimulatorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      widget.controller.screenshotter = _saveScreenshot;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Runs after every frame: tells touch emulation where the screen is and
  /// reads the status bar style the app's widgets ask for.
  void _afterFrame(Duration _) {
    if (!mounted) return;
    final RenderObject? screen = _screenKey.currentContext?.findRenderObject();
    if (screen is RenderBox && screen.attached && screen.hasSize) {
      _controller.touch.screenRect =
          MatrixUtils.transformRect(screen.getTransformTo(null), Offset.zero & screen.size);
    }
    final RenderObject? probe = _probeKey.currentContext?.findRenderObject();
    if (probe is _RenderStatusStyleProbe) {
      final SystemUiOverlayStyle? style = probe.styleAt(Offset(probe.size.width / 2, 1));
      _controller.setRegionStatusBarBrightness(style?.statusBarBrightness);
    }
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  /// Saves the screen at the device's native resolution, the way a phone
  /// screenshot comes out: status bar and keyboard included, Dynamic Island,
  /// home indicator and rounded corners not.
  Future<String?> _saveScreenshot() async {
    final RenderObject? boundary = _screenshotKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final DeviceProfile device = _controller.device;
    final ui.Image image = await boundary.toImage(pixelRatio: device.pixelRatio);
    final String directory = _controller.config.screenshotDir ??
        '${Platform.environment['HOME'] ?? '.'}/Pictures/iphoneSimulator';
    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:T]'), '-')
        .split('.')
        .first;
    final String orientation = _controller.landscape ? '-landscape' : '';
    final String path =
        '$directory/${_controller.config.appName}-${device.id}$orientation-$stamp.png';
    await _writePng(image, path);
    return path;
  }

  static Future<void> _writePng(ui.Image image, String path) async {
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) throw StateError('PNG encoding failed');
    final File file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
  }

  /// For CI and the project's own tests: capture the whole window once the
  /// app has settled, then quit.
  Future<void> _selfTest(String path) async {
    final int seconds = int.tryParse(Platform.environment['IPHONESIM_SELFTEST_DELAY'] ?? '') ?? 4;
    await Future<void>.delayed(Duration(seconds: seconds));
    final RenderObject? boundary = _windowKey.currentContext?.findRenderObject();
    if (boundary is RenderRepaintBoundary && mounted) {
      final double ratio = View.of(context).devicePixelRatio;
      await _writePng(await boundary.toImage(pixelRatio: ratio), path);
      final String? screen = await _saveScreenshot();
      stdout.writeln('[iphonesim] self-test: window $path, screen $screen');
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData window = MediaQuery.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFE5E5EA), fontSize: 13, height: 1.25),
        child: RepaintBoundary(
          key: _windowKey,
          child: ColoredBox(
            color: windowBackground,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) =>
                              _buildDevice(constraints, window),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Offstage(
                          offstage: _controller.panelVisible,
                          child: PanelButton(
                            label: 'Show panel',
                            onTap: () => _controller.panelVisible = true,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: IgnorePointer(child: Toast(message: _controller.toast)),
                      ),
                    ],
                  ),
                ),
                if (_controller.panelVisible) SimulatorPanel(controller: _controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevice(BoxConstraints constraints, MediaQueryData window) {
    final FrameGeometry geometry = FrameGeometry(_controller.device, landscape: _controller.landscape);
    final Size outer = geometry.outerSize;
    const double margin = 24;
    final double fit = math.min(
      (constraints.maxWidth - 2 * margin) / outer.width,
      (constraints.maxHeight - 2 * margin) / outer.height,
    );
    // "Fit" only shrinks: on a big monitor the phone stays at its real size.
    final double scale = _controller.zoom ?? fit.clamp(0.1, 1.0);

    return ClipRect(
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SizedBox(
          width: outer.width * scale,
          height: outer.height * scale,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox.fromSize(
              size: outer,
              child: DeviceFrame(
                geometry: geometry,
                screen: _buildScreen(geometry, window),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(FrameGeometry geometry, MediaQueryData window) {
    final SimulatorController c = _controller;
    final DeviceProfile device = geometry.device;
    final bool landscape = geometry.landscape;
    final bool dark = c.appearance == Brightness.dark;
    final double keyboardHeight = device.keyboardHeight(landscape: landscape);
    final double safeBottom = device.safeArea(landscape: landscape).bottom;

    return KeyedSubtree(
      key: _screenKey,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: c.keyboardVisible ? keyboardHeight : 0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: KeyedSubtree(key: _appKey, child: widget.app),
        builder: (BuildContext context, double keyboard, Widget? app) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  key: _screenshotKey,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: _StatusStyleProbe(
                          key: _probeKey,
                          child: MediaQuery(
                            data: simulatedMediaQuery(
                              window: window,
                              controller: c,
                              keyboard: keyboard,
                            ),
                            child: Shortcuts(shortcuts: linuxEditingShortcuts, child: app!),
                          ),
                        ),
                      ),
                      if (c.statusBarVisible)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: StatusBar(
                              device: device,
                              light: c.statusBarForeground == Brightness.light,
                              clean: c.cleanStatusBar,
                              use24HourFormat: window.alwaysUse24HourFormat,
                            ),
                          ),
                        ),
                      if (keyboard > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: keyboard - keyboardHeight,
                          height: keyboardHeight,
                          child: SoftwareKeyboard(dark: dark, bottomInset: safeBottom),
                        ),
                    ],
                  ),
                ),
              ),
              if (!device.homeButton)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: landscape ? 6 : 8,
                  child: IgnorePointer(
                    child: Center(child: HomeIndicator(landscape: landscape, dark: dark)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Ctrl+X/C/V/Z in text fields, as Linux users expect.
///
/// In iOS mode Flutter maps editing shortcuts to ⌘ (Super on Linux, which the
/// window manager usually takes). The Apple map leaves these Ctrl combinations
/// unused, so they reach this ancestor and run the focused field's own
/// copy/paste/undo actions. (Ctrl+A stays "start of line", as on a Mac.)
final Map<ShortcutActivator, Intent> linuxEditingShortcuts = <ShortcutActivator, Intent>{
  const SingleActivator(LogicalKeyboardKey.keyX, control: true):
      const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(LogicalKeyboardKey.keyC, control: true): CopySelectionTextIntent.copy,
  const SingleActivator(LogicalKeyboardKey.keyV, control: true):
      const PasteTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
      const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
      const RedoTextIntent(SelectionChangedCause.keyboard),
};

/// What the app sees: the phone's screen size, pixel density, safe areas and
/// keyboard, on top of the window's own settings (24-hour clock, animations...).
MediaQueryData simulatedMediaQuery({
  required MediaQueryData window,
  required SimulatorController controller,
  double keyboard = 0,
}) {
  final DeviceProfile device = controller.device;
  final bool landscape = controller.landscape;
  final Size size = Size(device.width, device.height);
  final Insets safe = device.safeArea(landscape: landscape);
  final EdgeInsets viewPadding = EdgeInsets.fromLTRB(safe.left, safe.top, safe.right, safe.bottom);
  return window.copyWith(
    size: landscape ? size.flipped : size,
    devicePixelRatio: device.pixelRatio,
    viewPadding: viewPadding,
    // Like UIKit: the keyboard covers the bottom safe area.
    padding: viewPadding.copyWith(bottom: math.max(0, viewPadding.bottom - keyboard)),
    viewInsets: EdgeInsets.only(bottom: keyboard),
    systemGestureInsets: EdgeInsets.zero,
    platformBrightness: controller.appearance,
    textScaler: TextScaler.linear(controller.textScale),
    navigationMode: NavigationMode.traditional,
    displayFeatures: const <ui.DisplayFeature>[],
  );
}

/// Marks the app's subtree as a repaint boundary so its layer tree can be
/// searched for the [SystemUiOverlayStyle] that AppBar,
/// CupertinoNavigationBar and AnnotatedRegion put under the status bar.
class _StatusStyleProbe extends SingleChildRenderObjectWidget {
  const _StatusStyleProbe({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStatusStyleProbe();
}

class _RenderStatusStyleProbe extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;

  SystemUiOverlayStyle? styleAt(Offset position) {
    final ContainerLayer? root = layer;
    if (root is! OffsetLayer || !root.attached) return null;
    // find() takes coordinates in the parent layer's space.
    return root.find<SystemUiOverlayStyle>(root.offset + position);
  }
}
