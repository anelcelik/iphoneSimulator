import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'devices.dart';
import 'fonts.dart';

/// The iOS status bar: time on the left, signal, Wi-Fi and battery on the right.
///
/// Shows the real time and (on a laptop) the real battery level. With [clean]
/// it shows 9:41 and full bars, like Apple's marketing shots and
/// `simctl status_bar override`.
class StatusBar extends StatefulWidget {
  const StatusBar({
    super.key,
    required this.device,
    required this.light,
    required this.clean,
    required this.use24HourFormat,
  });

  final DeviceProfile device;

  /// White text and icons (for dark backgrounds).
  final bool light;
  final bool clean;
  final bool use24HourFormat;

  /// Height of the area the bar draws in.
  static double heightFor(DeviceProfile device) => switch (device.cutout) {
        Cutout.dynamicIsland => 54,
        Cutout.notch => 47,
        Cutout.none => 20,
      };

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int? _battery = _readBattery();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final DateTime now = DateTime.now();
      final int? battery = _readBattery();
      if (now.minute != _now.minute || battery != _battery) {
        setState(() {
          _now = now;
          _battery = battery;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The laptop's battery level, if it has one.
  static int? _readBattery() {
    try {
      final Directory supplies = Directory('/sys/class/power_supply');
      if (!supplies.existsSync()) return null;
      for (final FileSystemEntity entry in supplies.listSync()) {
        final File type = File('${entry.path}/type');
        final File capacity = File('${entry.path}/capacity');
        if (type.existsSync() &&
            type.readAsStringSync().trim() == 'Battery' &&
            capacity.existsSync()) {
          return int.tryParse(capacity.readAsStringSync().trim());
        }
      }
    } catch (_) {
      // Not readable in a sandbox; show a full battery.
    }
    return null;
  }

  String get _time {
    if (widget.clean) return '9:41';
    final String minutes = _now.minute.toString().padLeft(2, '0');
    if (widget.use24HourFormat) return '${_now.hour.toString().padLeft(2, '0')}:$minutes';
    final int hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    return '$hour:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StatusBar.heightFor(widget.device),
      child: CustomPaint(
        size: Size.infinite,
        painter: _StatusBarPainter(
          device: widget.device,
          color: widget.light ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          time: _time,
          battery: widget.clean ? 100 : (_battery ?? 100),
          withAmPm: widget.device.cutout == Cutout.none && !widget.use24HourFormat && !widget.clean,
          amPm: _now.hour < 12 ? 'AM' : 'PM',
        ),
      ),
    );
  }
}

class _StatusBarPainter extends CustomPainter {
  _StatusBarPainter({
    required this.device,
    required this.color,
    required this.time,
    required this.battery,
    required this.withAmPm,
    required this.amPm,
  });

  final DeviceProfile device;
  final Color color;
  final String time;
  final int battery;
  final bool withAmPm;
  final String amPm;

  static const double _signalWidth = 17;
  static const double _wifiWidth = 15.5;
  static const double _batteryWidth = 27;
  static const double _gap = 5.5;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    switch (device.cutout) {
      case Cutout.dynamicIsland:
      case Cutout.notch:
        final bool island = device.cutout == Cutout.dynamicIsland;
        final double cutoutWidth = island ? 125 : 162;
        final double centerY = island ? 29.5 : 24;
        final double ear = (w - cutoutWidth) / 2;
        _drawText(canvas, time, 17, Offset(ear / 2 + 3, centerY));
        const double icons = _signalWidth + _gap + _wifiWidth + _gap + _batteryWidth;
        double x = w - ear / 2 - icons / 2 - 3;
        _drawSignal(canvas, Offset(x, centerY));
        x += _signalWidth + _gap;
        _drawWifi(canvas, Offset(x, centerY));
        x += _wifiWidth + _gap;
        _drawBattery(canvas, Offset(x, centerY));
      case Cutout.none:
        const double centerY = 10;
        _drawText(canvas, withAmPm ? '$time $amPm' : time, 12, Offset(w / 2, centerY));
        _drawSignal(canvas, const Offset(6, centerY), scale: 0.8);
        _drawWifi(canvas, const Offset(6 + _signalWidth * 0.8 + 4, centerY), scale: 0.8);
        final double batteryX = w - 6 - _batteryWidth * 0.85;
        _drawBattery(canvas, Offset(batteryX, centerY), scale: 0.85);
        _drawText(canvas, '$battery%', 12, Offset(batteryX - 18, centerY));
    }
  }

  void _drawText(Canvas canvas, String text, double fontSize, Offset center) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: iosTextFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: -0.4,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  /// Four bars, bottoms aligned. [origin] is the left edge at vertical center.
  void _drawSignal(Canvas canvas, Offset origin, {double scale = 1}) {
    final Paint paint = Paint()..color = color;
    const List<double> heights = <double>[4, 6.3, 8.6, 11];
    final double bottom = origin.dy + 5.5 * scale;
    for (int i = 0; i < heights.length; i++) {
      final double h = heights[i] * scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origin.dx + i * 4.6 * scale, bottom - h, 3.2 * scale, h),
          Radius.circular(1 * scale),
        ),
        paint,
      );
    }
  }

  /// Three stacked arcs fanning up from a point at the bottom.
  void _drawWifi(Canvas canvas, Offset origin, {double scale = 1}) {
    final Paint paint = Paint()..color = color;
    final Offset tip = Offset(origin.dx + _wifiWidth / 2 * scale, origin.dy + 5.5 * scale);
    const double start = -3 * 3.14159265 / 4;
    const double sweep = 3.14159265 / 2;
    final List<(double, double)> rings = <(double, double)>[(11, 8.3), (7.3, 4.8), (3.6, 0)];
    for (final (double outer, double inner) in rings) {
      final Path ring = Path()
        ..arcTo(Rect.fromCircle(center: tip, radius: outer * scale), start, sweep, true);
      if (inner == 0) {
        ring.lineTo(tip.dx, tip.dy);
      } else {
        ring.arcTo(Rect.fromCircle(center: tip, radius: inner * scale), start + sweep, -sweep, false);
      }
      ring.close();
      canvas.drawPath(ring, paint);
    }
  }

  /// Outline, fill proportional to the level, and the terminal cap.
  void _drawBattery(Canvas canvas, Offset origin, {double scale = 1}) {
    final double width = 24.5 * scale;
    final double height = 12 * scale;
    final Rect body = Rect.fromLTWH(origin.dx, origin.dy - height / 2, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.deflate(0.5), Radius.circular(3.6 * scale)),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Rect inner = body.deflate(2 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, inner.width * (battery.clamp(5, 100) / 100), inner.height),
        Radius.circular(2 * scale),
      ),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.right + 1, origin.dy - 2 * scale, 1.5 * scale, 4 * scale),
        Radius.circular(1 * scale),
      ),
      Paint()..color = color.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_StatusBarPainter old) =>
      old.color != color ||
      old.time != time ||
      old.battery != battery ||
      old.device != device ||
      old.withAmPm != withAmPm;
}
