import 'dart:ui' show Offset, Rect;

import 'package:flutter/gestures.dart';

/// Turns mouse clicks and drags on the simulated screen into touches, the way
/// Xcode's Simulator does: an iPhone app never sees a mouse.
///
/// Outside the screen (the control panel, the window background) the mouse
/// stays a mouse.
class TouchEmulation {
  /// The simulated screen in window coordinates (logical pixels). The shell
  /// updates it after every frame.
  Rect? screenRect;

  /// Device id for the synthesized touches; no real input device uses it.
  static const int touchDevice = 0x1F0E;

  final Set<int> _touching = <int>{};
  final Set<int> _dropped = <int>{};

  /// Returns the event to dispatch instead of [event], or `null` to drop it.
  PointerEvent? transform(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return event;
    final int pointer = event.pointer;
    final bool ends = event is PointerUpEvent || event is PointerCancelEvent;

    if (event is PointerDownEvent) {
      if (!_onScreen(event.position)) return event;
      // Right and middle clicks have no touch equivalent.
      if (event.buttons != kPrimaryMouseButton) {
        _dropped.add(pointer);
        return null;
      }
      _touching.add(pointer);
      return _asTouch(event);
    }
    if (_dropped.contains(pointer)) {
      if (ends) _dropped.remove(pointer);
      return null;
    }
    if (_touching.contains(pointer)) {
      if (ends) _touching.remove(pointer);
      if (event is PointerMoveEvent || ends) return _asTouch(event);
    }
    // Fingers don't hover: without this, apps would show desktop hover effects.
    if (event is PointerHoverEvent && _onScreen(event.position)) return null;
    return event;
  }

  bool _onScreen(Offset position) => screenRect?.contains(position) ?? false;

  static PointerEvent _asTouch(PointerEvent event) =>
      event.copyWith(kind: PointerDeviceKind.touch, device: touchDevice);
}
