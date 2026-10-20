import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'sources_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Selected tab; public so debug hooks can switch it.
  static final tab = ValueNotifier<int>(0);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _started = false;

  static const _items = [
    (Icons.explore_rounded, 'Discover'),
    (Icons.video_library_rounded, 'Library'),
    (Icons.bookmark_rounded, 'Watchlist'),
    (Icons.extension_rounded, 'Sources'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // Pick up new files on launch.
      AppServices.of(context).library.rescan();
    }
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      DiscoverScreen(),
      LibraryScreen(),
      WatchlistScreen(),
      SourcesScreen(),
      SettingsScreen(),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: HomeScreen.tab,
      builder: (context, index, _) => Scaffold(
        body: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
              child: Glass(
                radius: 24,
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      const SizedBox(height: 22),
                      const Text(
                        '夢',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: Palette.text,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (var i = 0; i < _items.length; i++)
                        _NavButton(
                          icon: _items[i].$1,
                          label: _items[i].$2,
                          selected: i == index,
                          onTap: () => HomeScreen.tab.value = i,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(index: index, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected ? Palette.glassStrong : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : Palette.textFaint,
            ),
          ),
        ),
      ),
    ),
  );
}
