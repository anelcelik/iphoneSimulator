import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'config.dart';
import 'devices.dart';
import 'messenger.dart';
import 'pointer.dart';

/// iOS Dynamic Type sizes and the text scale an app receives for each.
const List<(String, double)> dynamicTypeSizes = <(String, double)>[
  ('Extra Small', 0.824),
  ('Small', 0.882),
  ('Medium', 0.941),
  ('Large', 1.0),
  ('Extra Large', 1.118),
  ('XX Large', 1.235),
  ('XXX Large', 1.353),
  ('AX1', 1.647),
  ('AX2', 1.941),
  ('AX3', 2.353),
  ('AX4', 2.765),
  ('AX5', 3.118),
];

/// The iOS default ("Large").
const int defaultTextSize = 3;

/// Everything the simulator window shows and the app is told: chosen device,
/// orientation, appearance, plus what the app asked for through platform
/// channels (status bar style, keyboard, orientation lock).
class SimulatorController extends ChangeNotifier implements PlatformTraffic {
  SimulatorController(this.config)
      : _device = deviceById(config.device) ?? deviceProfiles.first {
    _load();
  }

  final SimulatorConfig config;
  final TouchEmulation touch = TouchEmulation();

  // Panel settings, remembered across runs.
  DeviceProfile _device;
  bool _landscape = false;
  Brightness _appearance = Brightness.light;
  int _textSize = defaultTextSize;
  bool _softwareKeyboard = true;
  bool _cleanStatusBar = false;
  double? _zoom; // null: fit the window
  bool _panelVisible = true;

  // What the app asked for.
  bool _keyboardRequested = false;
  Timer? _keyboardHideTimer;
  Brightness? _requestedStatusBarBrightness;
  Brightness? _regionStatusBarBrightness;
  bool _statusBarHidden = false;
  bool _portraitAllowed = true;
  bool _landscapeAllowed = true;

  /// Plugin calls that nothing on Linux answered, as "channel · method".
  final List<String> missingPlugins = <String>[];

  /// IPHONESIM_VERBOSE=1 logs the system calls the simulator reacts to.
  static final bool _verbose = Platform.environment['IPHONESIM_VERBOSE'] == '1';

  /// The font standing in for San Francisco, or null when none was found.
  String? systemFont;
  bool _fontsLoaded = false;

  String? _toast;
  Timer? _toastTimer;
  Timer? _saveTimer;

  /// Set by the shell; takes a screenshot of the simulated screen.
  Future<String?> Function()? screenshotter;

  DeviceProfile get device => _device;
  bool get landscape => _landscape;
  Brightness get appearance => _appearance;
  int get textSize => _textSize;
  double get textScale => dynamicTypeSizes[_textSize].$2;
  bool get softwareKeyboard => _softwareKeyboard;
  bool get cleanStatusBar => _cleanStatusBar;
  double? get zoom => _zoom;
  bool get panelVisible => _panelVisible;
  bool get fontsLoaded => _fontsLoaded;
  String? get toast => _toast;

  bool get portraitAllowed => _portraitAllowed;
  bool get landscapeAllowed => _landscapeAllowed;

  bool get keyboardVisible => _softwareKeyboard && _keyboardRequested;

  /// iPhones hide the status bar in landscape.
  bool get statusBarVisible => !_landscape && !_statusBarHidden;

  /// Brightness of the status bar *text*: [Brightness.light] means white.
  Brightness get statusBarForeground {
    // On iOS, statusBarBrightness describes the bar's background:
    // a dark background gets light text.
    final Brightness? background = _regionStatusBarBrightness ?? _requestedStatusBarBrightness;
    if (background != null) {
      return background == Brightness.dark ? Brightness.light : Brightness.dark;
    }
    return _appearance == Brightness.dark ? Brightness.light : Brightness.dark;
  }

  set device(DeviceProfile value) {
    if (identical(value, _device)) return;
    _device = value;
    _changed();
  }

  set landscape(bool value) {
    if (value == _landscape) return;
    if (value && !_landscapeAllowed) return;
    if (!value && !_portraitAllowed) return;
    _landscape = value;
    _changed();
  }

  set appearance(Brightness value) {
    if (value == _appearance) return;
    _appearance = value;
    _changed();
  }

  set textSize(int value) {
    final int clamped = value.clamp(0, dynamicTypeSizes.length - 1);
    if (clamped == _textSize) return;
    _textSize = clamped;
    _changed();
  }

  set softwareKeyboard(bool value) {
    if (value == _softwareKeyboard) return;
    _softwareKeyboard = value;
    _changed();
  }

  set cleanStatusBar(bool value) {
    if (value == _cleanStatusBar) return;
    _cleanStatusBar = value;
    _changed();
  }

  set zoom(double? value) {
    if (value == _zoom) return;
    _zoom = value;
    _changed();
  }

  set panelVisible(bool value) {
    if (value == _panelVisible) return;
    _panelVisible = value;
    _changed();
  }

  void setFonts(String? family) {
    systemFont = family;
    _fontsLoaded = true;
    _notify();
  }

  /// Called by the shell after each frame with the style of the
  /// AnnotatedRegion under the status bar (AppBar, CupertinoNavigationBar...).
  void setRegionStatusBarBrightness(Brightness? value) {
    if (value == _regionStatusBarBrightness) return;
    _regionStatusBarBrightness = value;
    _notify();
  }

  void showToast(String message) {
    _toast = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 4), () {
      _toast = null;
      _notify();
    });
    _notify();
  }

  Future<void> takeScreenshot() async {
    final Future<String?> Function()? shoot = screenshotter;
    if (shoot == null) return;
    try {
      final String? path = await shoot();
      if (path != null) showToast('Screenshot saved: $path');
    } catch (error) {
      showToast('Screenshot failed: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // PlatformTraffic

  @override
  void onPlatformCall(String method, Object? arguments) {
    if (_verbose) debugPrint('[iphonesim] flutter/platform $method $arguments');
    switch (method) {
      case 'SystemChrome.setSystemUIOverlayStyle':
        if (arguments is Map) {
          final Brightness? brightness = _parseBrightness(arguments['statusBarBrightness']);
          if (brightness != null && brightness != _requestedStatusBarBrightness) {
            _requestedStatusBarBrightness = brightness;
            _notify();
          }
        }
      case 'SystemChrome.setEnabledSystemUIMode':
        _setStatusBarHidden(arguments != 'SystemUiMode.edgeToEdge');
      case 'SystemChrome.setEnabledSystemUIOverlays':
        if (arguments is List) {
          _setStatusBarHidden(!arguments.contains('SystemUiOverlay.top'));
        }
      case 'SystemChrome.setPreferredOrientations':
        if (arguments is List) _setAllowedOrientations(arguments.cast<Object?>());
    }
  }

  @override
  void onTextInputCall(String method) {
    if (_verbose) debugPrint('[iphonesim] flutter/textinput $method');
    switch (method) {
      case 'TextInput.show':
        _keyboardHideTimer?.cancel();
        if (!_keyboardRequested) {
          _keyboardRequested = true;
          _notify();
        }
      case 'TextInput.hide':
      case 'TextInput.clearClient':
        // Moving focus between two fields closes one connection and opens the
        // next; wait a moment so the keyboard doesn't bounce.
        _keyboardHideTimer?.cancel();
        _keyboardHideTimer = Timer(const Duration(milliseconds: 80), () {
          if (_keyboardRequested) {
            _keyboardRequested = false;
            _notify();
          }
        });
    }
  }

  @override
  void onMissingPlugin(String channel, String? method) {
    final String entry = method == null ? channel : '$channel · $method';
    if (missingPlugins.contains(entry)) return;
    missingPlugins.add(entry);
    final String outcome = config.lenientPlugins
        ? 'answered with null'
        : 'threw MissingPluginException';
    debugPrint('[iphonesim] No Linux implementation for $entry ($outcome).');
    _notify();
  }

  void _setStatusBarHidden(bool hidden) {
    if (hidden == _statusBarHidden) return;
    _statusBarHidden = hidden;
    _notify();
  }

  void _setAllowedOrientations(List<Object?> orientations) {
    // An empty list means "anything the device supports".
    final bool any = orientations.isEmpty;
    _portraitAllowed = any || orientations.any((Object? o) => '$o'.contains('portrait'));
    _landscapeAllowed = any || orientations.any((Object? o) => '$o'.contains('landscape'));
    if (_landscape && !_landscapeAllowed) _landscape = false;
    if (!_landscape && !_portraitAllowed) _landscape = true;
    _notify();
  }

  static Brightness? _parseBrightness(Object? value) => switch (value) {
        'Brightness.dark' => Brightness.dark,
        'Brightness.light' => Brightness.light,
        _ => null,
      };

  // ---------------------------------------------------------------------------
  // Notifications and persistence

  void _changed() {
    _notify();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  /// Platform messages can arrive while a frame is being built; listeners
  /// rebuild widgets, so defer them to after the frame in that case.
  void _notify() {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  void _load() {
    final String? path = config.stateFile;
    if (path == null) return;
    try {
      final File file = File(path);
      if (!file.existsSync()) return;
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      final DeviceProfile? device = deviceById('${decoded['device']}');
      if (device != null) _device = device;
      _landscape = decoded['landscape'] == true;
      _appearance = decoded['dark'] == true ? Brightness.dark : Brightness.light;
      final Object? textSize = decoded['textSize'];
      if (textSize is int) _textSize = textSize.clamp(0, dynamicTypeSizes.length - 1);
      _softwareKeyboard = decoded['keyboard'] != false;
      _cleanStatusBar = decoded['cleanStatusBar'] == true;
      final Object? zoom = decoded['zoom'];
      _zoom = zoom is num ? zoom.toDouble() : null;
      _panelVisible = decoded['panel'] != false;
    } catch (error) {
      debugPrint('[iphonesim] Ignoring unreadable state file $path: $error');
    }
  }

  void _save() {
    final String? path = config.stateFile;
    if (path == null) return;
    try {
      final File file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(<String, Object?>{
        'device': _device.id,
        'landscape': _landscape,
        'dark': _appearance == Brightness.dark,
        'textSize': _textSize,
        'keyboard': _softwareKeyboard,
        'cleanStatusBar': _cleanStatusBar,
        'zoom': _zoom,
        'panel': _panelVisible,
      }));
    } catch (error) {
      debugPrint('[iphonesim] Could not save state to $path: $error');
    }
  }

  @override
  void dispose() {
    _keyboardHideTimer?.cancel();
    _toastTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
