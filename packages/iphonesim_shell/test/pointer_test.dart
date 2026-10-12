import 'dart:ui' show Rect;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphonesim_shell/iphonesim_shell.dart';

void main() {
  TouchEmulation emulation() =>
      TouchEmulation()..screenRect = const Rect.fromLTWH(100, 100, 400, 800);

  const Offset inside = Offset(200, 300);
  const Offset outside = Offset(20, 30);

  test('a click and drag on the screen becomes a touch', () {
    final TouchEmulation t = emulation();
    final PointerEvent? down = t.transform(
      const PointerDownEvent(kind: PointerDeviceKind.mouse, pointer: 7, position: inside, buttons: kPrimaryMouseButton),
    );
    expect(down, isA<PointerDownEvent>());
    expect(down!.kind, PointerDeviceKind.touch);

    // The drag continues as a touch even after leaving the screen.
    final PointerEvent? move = t.transform(
      const PointerMoveEvent(kind: PointerDeviceKind.mouse, pointer: 7, position: outside, buttons: kPrimaryMouseButton),
    );
    expect(move!.kind, PointerDeviceKind.touch);
    final PointerEvent? up = t.transform(const PointerUpEvent(kind: PointerDeviceKind.mouse, pointer: 7, position: outside));
    expect(up!.kind, PointerDeviceKind.touch);
  });

  test('the panel keeps getting mouse events', () {
    final TouchEmulation t = emulation();
    const PointerDownEvent down = PointerDownEvent(kind: PointerDeviceKind.mouse, pointer: 1, position: outside, buttons: kPrimaryMouseButton);
    expect(t.transform(down), same(down));
    const PointerHoverEvent hover = PointerHoverEvent(kind: PointerDeviceKind.mouse, position: outside);
    expect(t.transform(hover), same(hover));
  });

  test('hovering over the screen is dropped', () {
    expect(emulation().transform(const PointerHoverEvent(kind: PointerDeviceKind.mouse, position: inside)), isNull);
  });

  test('a right click on the screen is dropped with its whole gesture', () {
    final TouchEmulation t = emulation();
    expect(
      t.transform(const PointerDownEvent(kind: PointerDeviceKind.mouse, pointer: 3, position: inside, buttons: kSecondaryMouseButton)),
      isNull,
    );
    expect(t.transform(const PointerMoveEvent(kind: PointerDeviceKind.mouse, pointer: 3, position: inside, buttons: kSecondaryMouseButton)), isNull);
    expect(t.transform(const PointerUpEvent(kind: PointerDeviceKind.mouse, pointer: 3, position: inside)), isNull);
  });

  test('real touches and scroll wheels pass through', () {
    final TouchEmulation t = emulation();
    const PointerDownEvent touch = PointerDownEvent(kind: PointerDeviceKind.touch, position: inside);
    expect(t.transform(touch), same(touch));
    const PointerScrollEvent wheel = PointerScrollEvent(kind: PointerDeviceKind.mouse, position: inside, scrollDelta: Offset(0, 40));
    expect(t.transform(wheel), same(wheel));
  });
}
