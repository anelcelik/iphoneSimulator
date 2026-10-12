import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// What the simulator wants to know about the app's platform-channel traffic.
abstract class PlatformTraffic {
  /// A call on `flutter/platform` (SystemChrome, haptics, clipboard...).
  void onPlatformCall(String method, Object? arguments);

  /// A call on `flutter/textinput`.
  void onTextInputCall(String method);

  /// A plugin call that nothing on Linux answered.
  void onMissingPlugin(String channel, String? method);
}

/// Sits between the framework and the engine, so the simulator can:
///
/// * watch what an iOS app asks of the system (status bar style, hidden
///   status bar, orientation lock, keyboard), which the Linux embedder ignores;
/// * report plugins that have no Linux implementation and, when [lenient],
///   answer them with `null` so the app keeps running.
class SimulatorMessenger extends BinaryMessenger {
  SimulatorMessenger(this._inner, this._traffic, {required this.lenient});

  final BinaryMessenger _inner;
  final PlatformTraffic _traffic;
  final bool lenient;

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    // ignore: deprecated_member_use
    return _inner.handlePlatformMessage(channel, data, callback);
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    _observe(channel, message);
    final Future<ByteData?>? reply = _inner.send(channel, message);
    // Framework channels are the embedder's business; a null reply there is
    // normal and must stay null.
    if (reply == null || channel.startsWith('flutter/')) return reply;
    return reply.then((ByteData? data) {
      if (data != null) return data;
      _traffic.onMissingPlugin(channel, methodName(channel, message));
      return lenient ? emptyReply(channel, message) : null;
    });
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    _inner.setMessageHandler(channel, handler);
  }

  void _observe(String channel, ByteData? message) {
    if (message == null) return;
    if (channel == SystemChannels.platform.name) {
      final MethodCall? call = _decode(const JSONMethodCodec(), message);
      if (call != null) _traffic.onPlatformCall(call.method, call.arguments);
    } else if (channel == SystemChannels.textInput.name) {
      final MethodCall? call = _decode(const JSONMethodCodec(), message);
      if (call != null) _traffic.onTextInputCall(call.method);
    }
  }

  /// Best guess at the method a plugin message calls, for the log.
  static String? methodName(String channel, ByteData? message) {
    if (channel.startsWith('dev.flutter.pigeon.')) {
      return channel.substring(channel.lastIndexOf('.') + 1);
    }
    if (message == null) return null;
    return (_decode(const StandardMethodCodec(), message) ??
            _decode(const JSONMethodCodec(), message))
        ?.method;
  }

  /// A successful "nothing" in the codec the plugin most likely uses.
  ///
  /// Pigeon replies are a list (`[result]`), JSON method channels start with
  /// `{`, everything else is assumed to be the standard method codec.
  static ByteData? emptyReply(String channel, ByteData? message) {
    if (channel.startsWith('dev.flutter.pigeon.')) {
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    }
    if (message != null && message.lengthInBytes > 0 && message.getUint8(0) == 0x7B) {
      return const JSONMethodCodec().encodeSuccessEnvelope(null);
    }
    return const StandardMethodCodec().encodeSuccessEnvelope(null);
  }

  static MethodCall? _decode(MethodCodec codec, ByteData message) {
    try {
      return codec.decodeMethodCall(message);
    } catch (_) {
      return null;
    }
  }
}
