import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphonesim_shell/iphonesim_shell.dart';

/// Records what the app sees, and keeps a counter to prove its state survives
/// device and orientation changes.
class _ProbeApp extends StatefulWidget {
  const _ProbeApp({this.overlayStyle});

  final SystemUiOverlayStyle? overlayStyle;

  static MediaQueryData? lastMediaQuery;

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    _ProbeApp.lastMediaQuery = MediaQuery.of(context);
    final Widget body = Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => counter++),
        child: Center(child: Text('count $counter')),
      ),
    );
    final SystemUiOverlayStyle? style = widget.overlayStyle;
    if (style == null) return body;
    return AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: body);
  }
}

Future<SimulatorController> _pumpShell(
  WidgetTester tester, {
  SimulatorConfig config = const SimulatorConfig(),
  Widget app = const _ProbeApp(),
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final SimulatorController controller = SimulatorController(config);
  await tester.pumpWidget(SimulatorShell(controller: controller, app: app));
  await tester.pump();
  return controller;
}

/// Unmounts the shell, then disposes the controller and its timers.
Future<void> _tearDown(WidgetTester tester, SimulatorController controller) async {
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
}

void main() {
  testWidgets('the app sees the device screen, not the window', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(tester);
    final MediaQueryData data = _ProbeApp.lastMediaQuery!;
    expect(data.size, const Size(402, 874));
    expect(data.devicePixelRatio, 3);
    expect(data.padding, const EdgeInsets.fromLTRB(0, 62, 0, 34));
    expect(data.viewPadding, data.padding);
    expect(data.viewInsets, EdgeInsets.zero);
    expect(data.platformBrightness, Brightness.light);
    await _tearDown(tester, c);
  });

  testWidgets('rotation and device switches keep the app state', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(tester);
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    c.landscape = true;
    await tester.pump();
    expect(_ProbeApp.lastMediaQuery!.size, const Size(874, 402));
    expect(_ProbeApp.lastMediaQuery!.padding, const EdgeInsets.fromLTRB(62, 0, 62, 20));

    c.device = deviceById('iphone-se')!;
    await tester.pump();
    expect(_ProbeApp.lastMediaQuery!.size, const Size(667, 375));
    expect(_ProbeApp.lastMediaQuery!.devicePixelRatio, 2);
    expect(find.text('count 1'), findsOneWidget);
    await _tearDown(tester, c);
  });

  testWidgets('a text field asking for the keyboard gets viewInsets', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(tester);
    c.onTextInputCall('TextInput.show');
    await tester.pumpAndSettle();
    MediaQueryData data = _ProbeApp.lastMediaQuery!;
    expect(data.viewInsets.bottom, 336);
    expect(data.padding.bottom, 0, reason: 'the keyboard covers the bottom safe area');
    expect(data.viewPadding.bottom, 34);

    c.onTextInputCall('TextInput.clearClient');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    data = _ProbeApp.lastMediaQuery!;
    expect(data.viewInsets.bottom, 0);

    c.softwareKeyboard = false;
    c.onTextInputCall('TextInput.show');
    await tester.pumpAndSettle();
    expect(_ProbeApp.lastMediaQuery!.viewInsets.bottom, 0);
    await _tearDown(tester, c);
  });

  testWidgets('status bar text follows the AnnotatedRegion under it', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(
      tester,
      app: const _ProbeApp(overlayStyle: SystemUiOverlayStyle.light),
    );
    await tester.pump();
    expect(c.statusBarForeground, Brightness.light, reason: 'light style = white text');
    await _tearDown(tester, c);
  });

  testWidgets('status bar follows SystemChrome calls and dark mode', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(tester);
    expect(c.statusBarForeground, Brightness.dark);
    c.appearance = Brightness.dark;
    expect(c.statusBarForeground, Brightness.light);
    c.onPlatformCall('SystemChrome.setSystemUIOverlayStyle', <String, Object?>{
      'statusBarBrightness': 'Brightness.light',
    });
    expect(c.statusBarForeground, Brightness.dark);
    c.onPlatformCall('SystemChrome.setEnabledSystemUIMode', 'SystemUiMode.immersive');
    expect(c.statusBarVisible, isFalse);
    c.onPlatformCall('SystemChrome.setEnabledSystemUIMode', 'SystemUiMode.edgeToEdge');
    expect(c.statusBarVisible, isTrue);
    await _tearDown(tester, c);
  });

  testWidgets('an orientation lock disables the other orientation', (WidgetTester tester) async {
    final SimulatorController c = await _pumpShell(tester);
    c.landscape = true;
    c.onPlatformCall('SystemChrome.setPreferredOrientations', <String>['DeviceOrientation.portraitUp']);
    expect(c.landscape, isFalse);
    c.landscape = true;
    expect(c.landscape, isFalse);
    c.onPlatformCall('SystemChrome.setPreferredOrientations', <String>[]);
    c.landscape = true;
    expect(c.landscape, isTrue);
    await _tearDown(tester, c);
  });

  testWidgets('screenshots come out at the native resolution', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('iphonesim_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final SimulatorController c = await _pumpShell(
      tester,
      config: SimulatorConfig(appName: 'probe', screenshotDir: dir.path),
    );
    final String? path = await tester.runAsync<String?>(() => c.screenshotter!());
    expect(path, isNotNull);
    final Uint8List png = File(path!).readAsBytesSync();
    final ByteData header = ByteData.sublistView(png);
    expect(header.getUint32(16), 1206, reason: 'PNG width');
    expect(header.getUint32(20), 2622, reason: 'PNG height');
    expect(path, contains('probe-iphone-17-pro-'));
    await _tearDown(tester, c);
  });

  testWidgets('settings are remembered in the state file', (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('iphonesim_state');
    addTearDown(() => dir.deleteSync(recursive: true));
    final SimulatorConfig config = SimulatorConfig(stateFile: '${dir.path}/state.json');
    final SimulatorController first = SimulatorController(config)
      ..device = deviceById('iphone-16e')!
      ..appearance = Brightness.dark
      ..textSize = 6;
    await tester.pump(const Duration(milliseconds: 400));
    first.dispose();

    final SimulatorController second = SimulatorController(config);
    expect(second.device.id, 'iphone-16e');
    expect(second.appearance, Brightness.dark);
    expect(second.textSize, 6);
    second.dispose();
  });

  testWidgets('Ctrl+C and Ctrl+V work in text fields in iOS mode', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final TextEditingController text = TextEditingController(text: 'hello');
    final SimulatorController c = await _pumpShell(
      tester,
      app: CupertinoApp(home: CupertinoPageScaffold(child: Center(child: CupertinoTextField(controller: text)))),
    );
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      if (call.method == 'Clipboard.getData') return <String, Object?>{'text': ' world'};
      return null;
    });
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboard, 'hello');

    text.selection = const TextSelection.collapsed(offset: 5);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(text.text, 'hello world');

    await _tearDown(tester, c);
    text.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
