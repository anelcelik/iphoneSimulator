import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A small iOS-style app that exercises what the simulator provides: safe
/// areas, large titles, the keyboard, dark mode, Dynamic Type, a status bar
/// over a dark header, and a plugin that has no Linux implementation.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'iphonesim example',
      debugShowCheckedModeBanner: false,
      home: _Tabs(),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.square_list), label: 'Places'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.pencil), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.device_phone_portrait), label: 'Device'),
        ],
      ),
      tabBuilder: (BuildContext context, int index) => CupertinoTabView(
        builder: (BuildContext context) => switch (index) {
          0 => const _PlacesPage(),
          1 => const _NotesPage(),
          _ => const _DevicePage(),
        },
      ),
    );
  }
}

const List<(String, String)> _places = <(String, String)>[
  ('Vondelpark', 'Amsterdam'),
  ('Tiergarten', 'Berlin'),
  ('Retiro', 'Madrid'),
  ('Englischer Garten', 'Munich'),
  ('Stadtpark', 'Vienna'),
  ('Parc de la Ciutadella', 'Barcelona'),
  ('Hyde Park', 'London'),
  ('Villa Borghese', 'Rome'),
  ('Bryggen', 'Bergen'),
  ('Djurgården', 'Stockholm'),
];

class _PlacesPage extends StatelessWidget {
  const _PlacesPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          const CupertinoSliverNavigationBar(largeTitle: Text('Places')),
          SliverList.list(
            children: <Widget>[
              CupertinoListSection.insetGrouped(
                header: const Text('Parks'),
                children: <Widget>[
                  for (final (String name, String city) in _places)
                    CupertinoListTile(
                      title: Text(name),
                      subtitle: Text(city),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => _PlaceDetail(name: name, city: city)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceDetail extends StatelessWidget {
  const _PlaceDetail({required this.name, required this.city});

  final String name;
  final String city;

  @override
  Widget build(BuildContext context) {
    // A dark header: the status bar should switch to white text here.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: const Color(0xFF1B4332),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('‹ Places', style: TextStyle(color: Color(0xFFD8F3DC))),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
                  ),
                  Text(city, style: const TextStyle(fontSize: 17, color: Color(0xFFB7E4C7))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Swipe from the left edge to go back, like on a phone.',
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesPage extends StatefulWidget {
  const _NotesPage();

  @override
  State<_NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<_NotesPage> {
  final List<String> _notes = <String>['Bring a ball', 'Check the opening hours'];
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add() {
    final String value = _text.text.trim();
    if (value.isEmpty) return;
    setState(() => _notes.insert(0, value));
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Notes')),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  CupertinoListSection.insetGrouped(
                    children: <Widget>[for (final String note in _notes) CupertinoListTile(title: Text(note))],
                  ),
                ],
              ),
            ),
            // Stays above the keyboard thanks to the viewInsets the simulator reports.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoTextField(
                      controller: _text,
                      placeholder: 'New note',
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  CupertinoButton(onPressed: _add, child: const Text('Add')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePage extends StatefulWidget {
  const _DevicePage();

  @override
  State<_DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<_DevicePage> {
  static const MethodChannel _battery = MethodChannel('dev.iphonesim.example/battery');
  String _pluginResult = 'not called yet';
  bool _switch = true;

  Future<void> _callPlugin() async {
    // No plugin answers this channel on Linux. By default the simulator
    // answers with null and lists the call in its panel.
    try {
      final int? level = await _battery.invokeMethod<int>('level');
      setState(() => _pluginResult = 'returned $level');
    } on MissingPluginException {
      setState(() => _pluginResult = 'threw MissingPluginException');
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    String insets(EdgeInsets e) =>
        '${e.top.toStringAsFixed(0)} / ${e.right.toStringAsFixed(0)} / ${e.bottom.toStringAsFixed(0)} / ${e.left.toStringAsFixed(0)}';
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Device')),
      child: ListView(
        children: <Widget>[
          CupertinoListSection.insetGrouped(
            header: const Text('What the app sees'),
            children: <Widget>[
              CupertinoListTile(
                title: const Text('Platform'),
                additionalInfo: Text(defaultTargetPlatform.name),
              ),
              CupertinoListTile(
                title: const Text('Screen'),
                additionalInfo: Text('${media.size.width.round()} × ${media.size.height.round()} pt'),
              ),
              CupertinoListTile(
                title: const Text('Pixel ratio'),
                additionalInfo: Text('${media.devicePixelRatio}'),
              ),
              CupertinoListTile(
                title: const Text('Safe area'),
                additionalInfo: Text(insets(media.padding)),
              ),
              CupertinoListTile(
                title: const Text('Appearance'),
                additionalInfo: Text(media.platformBrightness.name),
              ),
              CupertinoListTile(
                title: const Text('Text scale'),
                additionalInfo: Text(media.textScaler.scale(1).toStringAsFixed(2)),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('Try'),
            children: <Widget>[
              CupertinoListTile(
                title: const Text('A switch'),
                trailing: CupertinoSwitch(value: _switch, onChanged: (bool v) => setState(() => _switch = v)),
              ),
              CupertinoListTile(
                title: const Text('Call a missing plugin'),
                subtitle: Text(_pluginResult),
                onTap: _callPlugin,
              ),
              CupertinoListTile(
                title: const Text('Show an action sheet'),
                onTap: () => showCupertinoModalPopup<void>(
                  context: context,
                  builder: (BuildContext context) => CupertinoActionSheet(
                    title: const Text('Share park'),
                    actions: <Widget>[
                      CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Messages')),
                      CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Mail')),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      isDefaultAction: true,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
