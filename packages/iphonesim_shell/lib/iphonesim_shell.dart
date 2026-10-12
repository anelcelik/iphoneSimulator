/// The simulator window that `iphonesim run` puts around a Flutter app.
///
/// Apps don't depend on this package: the CLI copies it into
/// `build/iphonesim/shell/` and generates an entrypoint that calls
/// [runSimulated] with the app's own `main`.
library;

export 'src/binding.dart' show SimulatorBinding, runSimulated;
export 'src/config.dart';
export 'src/controller.dart' show SimulatorController, dynamicTypeSizes, defaultTextSize;
export 'src/devices.dart';
export 'src/messenger.dart' show PlatformTraffic, SimulatorMessenger;
export 'src/pointer.dart';
export 'src/shell.dart' show SimulatorShell, simulatedMediaQuery;
