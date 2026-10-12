// Device profiles shared by the shell and the CLI.
//
// Keep this file free of Flutter imports: the CLI embeds a copy of it.
//
// Sizes are logical points as UIKit reports them. Safe areas, corner radii and
// keyboard heights come from public measurements and can be off by a point or
// two; they are close enough for layout work, not for pixel-perfect mock-ups.

/// The hardware cut-out at the top of the screen.
enum Cutout { dynamicIsland, notch, none }

/// Safe-area insets in points.
class Insets {
  const Insets(this.top, this.right, this.bottom, this.left);

  final double top;
  final double right;
  final double bottom;
  final double left;
}

class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.safeAreaPortrait,
    required this.safeAreaLandscape,
    required this.cornerRadius,
    required this.cutout,
    required this.keyboardPortrait,
    required this.keyboardLandscape,
    this.homeButton = false,
  });

  /// Stable id used on the command line and in saved state.
  final String id;
  final String name;

  /// Portrait screen size in points.
  final double width;
  final double height;
  final double pixelRatio;

  final Insets safeAreaPortrait;
  final Insets safeAreaLandscape;

  /// Radius of the screen corners in points (0 for square screens).
  final double cornerRadius;
  final Cutout cutout;
  final bool homeButton;

  /// Software keyboard height including the suggestion bar, in points.
  final double keyboardPortrait;
  final double keyboardLandscape;

  Insets safeArea({required bool landscape}) =>
      landscape ? safeAreaLandscape : safeAreaPortrait;

  double keyboardHeight({required bool landscape}) =>
      landscape ? keyboardLandscape : keyboardPortrait;

  int get pixelWidth => (width * pixelRatio).round();
  int get pixelHeight => (height * pixelRatio).round();
}

const String defaultDeviceId = 'iphone-17-pro';

const List<DeviceProfile> deviceProfiles = <DeviceProfile>[
  DeviceProfile(
    id: 'iphone-17-pro',
    name: 'iPhone 17 Pro',
    width: 402,
    height: 874,
    pixelRatio: 3,
    safeAreaPortrait: Insets(62, 0, 34, 0),
    safeAreaLandscape: Insets(0, 62, 20, 62),
    cornerRadius: 62,
    cutout: Cutout.dynamicIsland,
    keyboardPortrait: 336,
    keyboardLandscape: 209,
  ),
  DeviceProfile(
    id: 'iphone-17-pro-max',
    name: 'iPhone 17 Pro Max',
    width: 440,
    height: 956,
    pixelRatio: 3,
    safeAreaPortrait: Insets(62, 0, 34, 0),
    safeAreaLandscape: Insets(0, 62, 20, 62),
    cornerRadius: 62,
    cutout: Cutout.dynamicIsland,
    keyboardPortrait: 346,
    keyboardLandscape: 209,
  ),
  DeviceProfile(
    id: 'iphone-17',
    name: 'iPhone 17',
    width: 402,
    height: 874,
    pixelRatio: 3,
    safeAreaPortrait: Insets(62, 0, 34, 0),
    safeAreaLandscape: Insets(0, 62, 20, 62),
    cornerRadius: 62,
    cutout: Cutout.dynamicIsland,
    keyboardPortrait: 336,
    keyboardLandscape: 209,
  ),
  DeviceProfile(
    id: 'iphone-16',
    name: 'iPhone 16',
    width: 393,
    height: 852,
    pixelRatio: 3,
    safeAreaPortrait: Insets(59, 0, 34, 0),
    safeAreaLandscape: Insets(0, 59, 21, 59),
    cornerRadius: 55,
    cutout: Cutout.dynamicIsland,
    keyboardPortrait: 336,
    keyboardLandscape: 209,
  ),
  DeviceProfile(
    id: 'iphone-16e',
    name: 'iPhone 16e',
    width: 390,
    height: 844,
    pixelRatio: 3,
    safeAreaPortrait: Insets(47, 0, 34, 0),
    safeAreaLandscape: Insets(0, 47, 21, 47),
    cornerRadius: 47.33,
    cutout: Cutout.notch,
    keyboardPortrait: 336,
    keyboardLandscape: 209,
  ),
  DeviceProfile(
    id: 'iphone-se',
    name: 'iPhone SE (3rd gen)',
    width: 375,
    height: 667,
    pixelRatio: 2,
    safeAreaPortrait: Insets(20, 0, 0, 0),
    safeAreaLandscape: Insets(0, 0, 0, 0),
    cornerRadius: 0,
    cutout: Cutout.none,
    homeButton: true,
    keyboardPortrait: 260,
    keyboardLandscape: 200,
  ),
];

DeviceProfile? deviceById(String id) {
  for (final device in deviceProfiles) {
    if (device.id == id) return device;
  }
  return null;
}
