import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'devices.dart';

/// The window around the phone.
const Color windowBackground = Color(0xFF151517);

/// Where the screen sits inside the drawn device body.
///
/// The body is drawn programmatically (no Apple artwork) in portrait and
/// rotated a quarter turn counter-clockwise for landscape, so the Dynamic
/// Island ends up on the left.
class FrameGeometry {
  FrameGeometry(this.device, {required this.landscape});

  final DeviceProfile device;
  final bool landscape;

  /// Bezel around the screen in portrait.
  EdgeInsets get portraitBezel => device.homeButton
      ? const EdgeInsets.fromLTRB(22, 76, 22, 76)
      : const EdgeInsets.all(13);

  /// Bezel in the current orientation (portrait top becomes landscape left).
  EdgeInsets get bezel {
    final EdgeInsets b = portraitBezel;
    if (!landscape) return b;
    return EdgeInsets.fromLTRB(b.top, b.right, b.bottom, b.left);
  }

  Size get portraitScreenSize => Size(device.width, device.height);

  Size get screenSize => landscape ? portraitScreenSize.flipped : portraitScreenSize;

  Size get outerSize => bezel.inflateSize(screenSize);

  Size get portraitOuterSize => portraitBezel.inflateSize(portraitScreenSize);

  double get bodyRadius => device.cornerRadius > 0 ? device.cornerRadius + 13 : 58;
}

/// The phone: body behind the screen, Dynamic Island or notch in front.
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.geometry, required this.screen});

  final FrameGeometry geometry;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BodyPainter(geometry),
      foregroundPainter: _CutoutPainter(geometry),
      child: Padding(
        padding: geometry.bezel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(geometry.device.cornerRadius),
          // With a plain clip, Impeller lets BackdropFilters (CupertinoTabBar's
          // blur) draw past the rounded corners. Clipping a layer holds.
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: screen,
        ),
      ),
    );
  }
}

/// Rotates the canvas so painters can always draw in portrait coordinates.
void _toPortrait(Canvas canvas, Size size, FrameGeometry geometry) {
  if (!geometry.landscape) return;
  canvas.translate(0, size.height);
  canvas.rotate(-math.pi / 2);
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.geometry);

  final FrameGeometry geometry;

  static const Color _body = Color(0xFF1C1C1E);
  static const Color _edge = Color(0xFF55555A);
  static const Color _button = Color(0xFF3A3A3D);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _toPortrait(canvas, size, geometry);
    final Size portrait = geometry.portraitOuterSize;
    final double h = portrait.height;
    final DeviceProfile device = geometry.device;

    // Side buttons, drawn first so the body overlaps their inner edge.
    final Paint button = Paint()..color = _button;
    void sideButton(bool left, double from, double to) {
      final double x = left ? -3 : portrait.width - 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h * from, 4, h * (to - from)), const Radius.circular(2)),
        button,
      );
    }

    if (device.homeButton) {
      sideButton(true, 0.13, 0.16);
      sideButton(true, 0.20, 0.26);
      sideButton(true, 0.29, 0.35);
      sideButton(false, 0.20, 0.27);
    } else {
      sideButton(true, 0.16, 0.20);
      sideButton(true, 0.24, 0.31);
      sideButton(true, 0.33, 0.40);
      sideButton(false, 0.26, 0.37);
    }

    final RRect body = RRect.fromRectAndRadius(Offset.zero & portrait, Radius.circular(geometry.bodyRadius));
    canvas.drawRRect(body, Paint()..color = _body);
    canvas.drawRRect(
      body.deflate(1),
      Paint()
        ..color = _edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Black glass under the screen, visible while the app draws nothing.
    final EdgeInsets bezel = geometry.portraitBezel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bezel.deflateRect(Offset.zero & portrait), Radius.circular(device.cornerRadius)),
      Paint()..color = const Color(0xFF000000),
    );

    if (device.homeButton) {
      final Offset center = Offset(portrait.width / 2, h - bezel.bottom / 2);
      canvas.drawCircle(
        center,
        bezel.bottom * 0.34,
        Paint()
          ..color = _edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // Earpiece above the screen.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(portrait.width / 2, bezel.top / 2), width: 52, height: 6),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF2C2C2E),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.geometry.device != geometry.device || old.geometry.landscape != geometry.landscape;
}

/// Hardware that covers the screen: the Dynamic Island or the notch.
class _CutoutPainter extends CustomPainter {
  _CutoutPainter(this.geometry);

  final FrameGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final DeviceProfile device = geometry.device;
    canvas.save();
    _toPortrait(canvas, size, geometry);
    final EdgeInsets bezel = geometry.portraitBezel;

    final double centerX = bezel.left + device.width / 2;
    final Paint black = Paint()..color = const Color(0xFF000000);

    switch (device.cutout) {
      case Cutout.dynamicIsland:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(centerX - 62.5, bezel.top + 11, 125, 37),
            const Radius.circular(18.5),
          ),
          black,
        );
        // The front camera, barely visible inside the island.
        canvas.drawCircle(Offset(centerX + 44, bezel.top + 29.5), 6, Paint()..color = const Color(0xFF0B0B10));
      case Cutout.notch:
        const double width = 162;
        const double height = 32;
        final double left = centerX - width / 2;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, bezel.top - 1, width, height + 1),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
          black,
        );
        // Small concave fillets where the notch meets the top edge.
        for (final double x in <double>[left, left + width]) {
          final double dir = x == left ? -1 : 1;
          final Path fillet = Path()
            ..moveTo(x, bezel.top)
            ..lineTo(x + dir * 6, bezel.top)
            ..quadraticBezierTo(x, bezel.top, x, bezel.top + 6)
            ..close();
          canvas.drawPath(fillet, black);
        }
      case Cutout.none:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CutoutPainter old) =>
      old.geometry.device != geometry.device || old.geometry.landscape != geometry.landscape;
}

/// The bar at the bottom of Face ID iPhones. Not part of screenshots, like on
/// a real device.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key, required this.landscape, required this.dark});

  final bool landscape;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: landscape ? 214 : 139,
      height: 5,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}
