import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'devices.dart';

// The panel sits above the app's MaterialApp/CupertinoApp, so it can't use
// their widgets (no Theme, Overlay or icon font up here). Everything below is
// plain widgets.

const Color _panelBackground = Color(0xFF1F1F22);
const Color _divider = Color(0xFF2E2E32);
const Color _muted = Color(0xFF8E8E93);
const Color _accent = Color(0xFF0A84FF);
const Color _control = Color(0xFF2C2C30);

/// Settings next to the phone: device, appearance, orientation, text size,
/// keyboard, status bar, zoom, screenshots and the plugin log.
class SimulatorPanel extends StatelessWidget {
  const SimulatorPanel({super.key, required this.controller});

  final SimulatorController controller;

  @override
  Widget build(BuildContext context) {
    final SimulatorController c = controller;
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: _panelBackground,
        border: Border(left: BorderSide(color: _divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'iphoneSimulator',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                PanelButton(label: 'Hide', onTap: () => c.panelVisible = false),
              ],
            ),
            const _Header('Device'),
            for (final DeviceProfile device in deviceProfiles)
              _Choice(
                label: device.name,
                detail: '${device.width.round()}×${device.height.round()}',
                selected: device == c.device,
                onTap: () => c.device = device,
              ),
            const _Header('Appearance'),
            _Segmented(
              options: const <String>['Light', 'Dark'],
              selected: c.appearance == Brightness.dark ? 1 : 0,
              onSelect: (int i) => c.appearance = i == 1 ? Brightness.dark : Brightness.light,
            ),
            const _Header('Orientation'),
            _Segmented(
              options: const <String>['Portrait', 'Landscape'],
              selected: c.landscape ? 1 : 0,
              enabled: <bool>[c.portraitAllowed, c.landscapeAllowed],
              onSelect: (int i) => c.landscape = i == 1,
            ),
            if (!c.landscapeAllowed || !c.portraitAllowed)
              const _Note('The app locks its orientation.'),
            const _Header('Text size'),
            _Stepper(
              value: dynamicTypeSizes[c.textSize].$1,
              onMinus: c.textSize > 0 ? () => c.textSize = c.textSize - 1 : null,
              onPlus: c.textSize < dynamicTypeSizes.length - 1 ? () => c.textSize = c.textSize + 1 : null,
            ),
            const _Header('Options'),
            _Toggle(
              label: 'Software keyboard',
              value: c.softwareKeyboard,
              onChanged: (bool v) => c.softwareKeyboard = v,
            ),
            _Toggle(
              label: 'Clean status bar (9:41)',
              value: c.cleanStatusBar,
              onChanged: (bool v) => c.cleanStatusBar = v,
            ),
            const _Header('Zoom'),
            _Segmented(
              options: const <String>['Fit', '50%', '75%', '100%'],
              selected: switch (c.zoom) {
                0.5 => 1,
                0.75 => 2,
                1.0 => 3,
                _ => 0,
              },
              onSelect: (int i) => c.zoom = const <double?>[null, 0.5, 0.75, 1.0][i],
            ),
            const SizedBox(height: 16),
            PanelButton(
              label: 'Save screenshot (${c.device.pixelWidth}×${c.device.pixelHeight})',
              primary: true,
              onTap: c.takeScreenshot,
            ),
            const _Header('Font'),
            _Note(
              !c.fontsLoaded
                  ? 'Looking for a San Francisco stand-in…'
                  : c.systemFont != null
                      ? '${c.systemFont} stands in for San Francisco.'
                      : 'No SF Pro or Inter installed: text uses the Linux default font. '
                          'Run `iphonesim doctor` for how to fix it.',
            ),
            _Header('Plugins without Linux support (${c.missingPlugins.length})'),
            if (c.missingPlugins.isEmpty)
              const _Note('None called so far.')
            else ...<Widget>[
              for (final String entry in c.missingPlugins.reversed.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(entry, style: const TextStyle(fontSize: 11, color: Color(0xFFFFB340))),
                ),
              _Note(
                c.config.lenientPlugins
                    ? 'These calls were answered with null so the app keeps running.'
                    : 'These calls threw MissingPluginException (--strict-plugins).',
              ),
            ],
            const SizedBox(height: 14),
            const _Note('Hot reload: press r in the terminal. Hot restart: R.'),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 5),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 10.5, color: _muted, letterSpacing: 0.6, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: _muted)),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.detail, required this.selected, required this.onTap});

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? const Color(0x330A84FF) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: selected ? const Color(0xFFFFFFFF) : null),
              ),
            ),
            Text(detail, style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, required this.onSelect, this.enabled});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<bool>? enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _control, borderRadius: BorderRadius.circular(7)),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: _Tap(
                onTap: (enabled?[i] ?? true) ? () => onSelect(i) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: i == selected ? const Color(0xFF636366) : null,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: (enabled?[i] ?? true) ? null : const Color(0xFF58585C),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onMinus, required this.onPlus});

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget step(String label, VoidCallback? onTap) => _Tap(
          onTap: onTap,
          child: Container(
            width: 34,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _control, borderRadius: BorderRadius.circular(6)),
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: onTap == null ? const Color(0xFF58585C) : null),
            ),
          ),
        );
    return Row(
      children: <Widget>[
        step('−', onMinus),
        Expanded(child: Text(value, textAlign: TextAlign.center)),
        step('+', onPlus),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF30D158) : const Color(0xFF48484A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PanelButton extends StatelessWidget {
  const PanelButton({super.key, required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        alignment: primary ? Alignment.center : null,
        decoration: BoxDecoration(
          color: primary ? _accent : _control,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: primary ? FontWeight.w600 : null, color: const Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}

/// A short message at the bottom of the window.
class Toast extends StatelessWidget {
  const Toast({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: message == null ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xEE2C2C30), borderRadius: BorderRadius.circular(8)),
          child: Text(message ?? '', style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
