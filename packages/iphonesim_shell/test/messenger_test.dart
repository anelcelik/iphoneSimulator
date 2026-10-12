import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphonesim_shell/iphonesim_shell.dart';

/// An engine where no plugin is registered: every message gets a null reply.
class _NoPlugins extends BinaryMessenger {
  final List<String> sent = <String>[];

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(String channel, ByteData? data, ui.PlatformMessageResponseCallback? callback) async {}

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    sent.add(channel);
    return Future<ByteData?>.value();
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {}
}

class _Traffic implements PlatformTraffic {
  final List<String> calls = <String>[];
  final List<String> missing = <String>[];

  @override
  void onPlatformCall(String method, Object? arguments) => calls.add(method);

  @override
  void onTextInputCall(String method) => calls.add(method);

  @override
  void onMissingPlugin(String channel, String? method) => missing.add('$channel#$method');
}

void main() {
  test('lenient mode answers a method channel call with null', () async {
    final _Traffic traffic = _Traffic();
    final SimulatorMessenger messenger = SimulatorMessenger(_NoPlugins(), traffic, lenient: true);
    final MethodChannel channel = MethodChannel('plugins.example/thing', const StandardMethodCodec(), messenger);
    expect(await channel.invokeMethod<String>('getThing'), isNull);
    expect(traffic.missing, <String>['plugins.example/thing#getThing']);
  });

  test('strict mode keeps MissingPluginException', () async {
    final SimulatorMessenger messenger = SimulatorMessenger(_NoPlugins(), _Traffic(), lenient: false);
    final MethodChannel channel = MethodChannel('plugins.example/thing', const StandardMethodCodec(), messenger);
    expect(() => channel.invokeMethod<void>('getThing'), throwsA(isA<MissingPluginException>()));
  });

  test('pigeon calls get a one-element reply list', () async {
    final _Traffic traffic = _Traffic();
    final SimulatorMessenger messenger = SimulatorMessenger(_NoPlugins(), traffic, lenient: true);
    const String name = 'dev.flutter.pigeon.quick_actions_ios.IOSQuickActionsApi.clearShortcutItems';
    final ByteData? reply = await messenger.send(name, const StandardMessageCodec().encodeMessage(<Object?>[]));
    expect(const StandardMessageCodec().decodeMessage(reply), <Object?>[null]);
    expect(traffic.missing, <String>['$name#clearShortcutItems']);
  });

  test('JSON method channels get a JSON reply', () async {
    final SimulatorMessenger messenger = SimulatorMessenger(_NoPlugins(), _Traffic(), lenient: true);
    final MethodChannel channel = MethodChannel('plugins.example/json', const JSONMethodCodec(), messenger);
    expect(await channel.invokeMethod<Object?>('ping', <String, int>{'a': 1}), isNull);
  });

  test('framework channels are passed through untouched and observed', () async {
    final _Traffic traffic = _Traffic();
    final SimulatorMessenger messenger = SimulatorMessenger(_NoPlugins(), traffic, lenient: true);
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('SystemChrome.setSystemUIOverlayStyle', <String, String>{'statusBarBrightness': 'Brightness.dark'}),
    );
    expect(await messenger.send('flutter/platform', message), isNull);
    final ByteData show = const JSONMethodCodec().encodeMethodCall(const MethodCall('TextInput.show'));
    expect(await messenger.send('flutter/textinput', show), isNull);
    expect(traffic.calls, <String>['SystemChrome.setSystemUIOverlayStyle', 'TextInput.show']);
    expect(traffic.missing, isEmpty);
  });
}
