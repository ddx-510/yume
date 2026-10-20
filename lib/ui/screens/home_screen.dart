import 'package:flutter/material.dart';

import '../../app_services.dart';
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
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => HomeScreen.tab.value = i,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 28, bottom: 12),
                child: Text(
                  '夢',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.video_library_outlined),
                  selectedIcon: Icon(Icons.video_library),
                  label: Text('Library'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: Text('Watchlist'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.extension_outlined),
                  selectedIcon: Icon(Icons.extension),
                  label: Text('Sources'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(index: index, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}
