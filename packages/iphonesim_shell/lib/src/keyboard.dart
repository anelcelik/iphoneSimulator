import 'package:flutter/widgets.dart';

import 'fonts.dart';

/// A look-alike of the iOS keyboard.
///
/// It's there so screens lay out the way they will on a phone when a text
/// field is focused (the app receives matching `viewInsets`). Typing happens
/// on the computer's keyboard; the keys here are a picture.
class SoftwareKeyboard extends StatelessWidget {
  const SoftwareKeyboard({super.key, required this.dark, required this.bottomInset});

  final bool dark;

  /// Space below the keys (the home-indicator area on Face ID iPhones).
  final double bottomInset;

  static const List<String> _row1 = <String>['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const List<String> _row2 = <String>['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const List<String> _row3 = <String>['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  @override
  Widget build(BuildContext context) {
    final Color background = dark ? const Color(0xFF2B2B2D) : const Color(0xFFD1D3D9);
    final Color key = dark ? const Color(0xFF6B6B6E) : const Color(0xFFFFFFFF);
    final Color special = dark ? const Color(0xFF464648) : const Color(0xFFABB0BA);
    final Color label = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final Color hint = dark ? const Color(0x99FFFFFF) : const Color(0x99000000);

    Widget cap(String text, Color color, {int flex = 10, double fontSize = 22}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x59000000), offset: Offset(0, 1)),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: iosTextFamily,
                  fontSize: fontSize,
                  color: label,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys, {double inset = 0}) => Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(3 + inset, 6, 3 + inset, 6),
            child: Row(children: keys),
          ),
        );

    // Absorb taps: on a phone, touching the keyboard never reaches the app.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    'Type on your computer keyboard',
                    style: TextStyle(fontFamily: iosTextFamily, fontSize: 15, color: hint),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    children: <Widget>[
                      row(<Widget>[for (final String k in _row1) cap(k, key)]),
                      row(<Widget>[for (final String k in _row2) cap(k, key)], inset: 16),
                      row(<Widget>[
                        cap('⇧', special, flex: 14, fontSize: 18),
                        const Spacer(flex: 2),
                        for (final String k in _row3) cap(k, key),
                        const Spacer(flex: 2),
                        cap('⌫', special, flex: 14, fontSize: 18),
                      ]),
                      row(<Widget>[
                        cap('123', special, flex: 25, fontSize: 16),
                        cap('space', key, flex: 50, fontSize: 16),
                        cap('return', special, flex: 25, fontSize: 16),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
