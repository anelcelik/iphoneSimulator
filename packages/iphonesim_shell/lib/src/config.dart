import 'devices.dart';

/// Settings the CLI writes into the generated entrypoint.
class SimulatorConfig {
  const SimulatorConfig({
    this.device = defaultDeviceId,
    this.lenientPlugins = true,
    this.iosFromStart = false,
    this.appName = 'app',
    this.stateFile,
    this.screenshotDir,
  });

  /// Device shown when there is no saved state yet.
  final String device;

  /// Answer calls to plugins that have no Linux implementation with `null`
  /// instead of throwing [MissingPluginException].
  final bool lenientPlugins;

  /// Report iOS from the first line of `main()` instead of from `runApp()`.
  ///
  /// Off by default: code that runs before `runApp()` usually sets up
  /// platform services (databases, file paths), and those need the real
  /// platform to pick their Linux implementation.
  final bool iosFromStart;

  /// Used in screenshot file names.
  final String appName;

  /// Where device, orientation and the other panel settings are remembered.
  final String? stateFile;

  /// Where screenshots go. Defaults to `~/Pictures/iphoneSimulator`.
  final String? screenshotDir;
}
