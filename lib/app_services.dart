import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'danmaku/dandanplay_client.dart';
import 'services/cover_cache.dart';
import 'services/json_store.dart';
import 'services/library_service.dart';
import 'services/metadata/metadata_service.dart';
import 'services/progress_service.dart';
import 'services/settings_service.dart';
import 'services/sync/trackers.dart';
import 'services/watchlist_service.dart';
import 'sources/direct_url_source.dart';
import 'sources/local_source.dart';
import 'sources/media_source.dart';

/// Wires up all services. Accessed from widgets via [AppServices.of].
class AppServices {
  AppServices._(this.dataDir);

  final Directory dataDir;
  late final SettingsService settings;
  late final MetadataService metadata;
  late final LibraryService library;
  late final ProgressService progress;
  late final WatchlistService watchlist;
  late final CoverCache covers;
  final sources = SourceRegistry();

  static Future<AppServices> create() async {
    final dir = await getApplicationSupportDirectory();
    final s = AppServices._(dir);
    s.settings = SettingsService(JsonStore(dir, 'settings'));
    await s.settings.load();
    s.metadata = MetadataService(s.settings);
    s.library = LibraryService(
      JsonStore(dir, 'library'),
      s.settings,
      s.metadata,
    );
    s.progress = ProgressService(JsonStore(dir, 'progress'));
    s.watchlist = WatchlistService(
      JsonStore(dir, 'watchlist'),
      s.settings,
      s.library,
      [
        AniListTracker(s.settings, s.metadata.anilist),
        BangumiTracker(s.settings, s.metadata.bangumi),
      ],
    );
    s.covers = CoverCache(s.cacheDir);
    await Future.wait([
      s.library.load(),
      s.progress.load(),
      s.watchlist.load(),
    ]);

    // Plug-in sources. Add new legal sources here.
    s.sources
      ..register(LocalLibrarySource(s.library))
      ..register(DirectUrlSource());
    await s.sources.initAll();
    return s;
  }

  /// Cache for covers and danmaku: explicit setting, else `.yume/cache` in the
  /// first library folder if that disk is mounted and writable, else the
  /// app's own support dir.
  Future<Directory> cacheDir() async {
    final configured = settings.value.cacheDir;
    if (configured.isNotEmpty) return Directory(configured);
    final roots = settings.value.libraryPaths;
    if (roots.isNotEmpty && await Directory(roots.first).exists()) {
      final d = Directory(p.join(roots.first, '.yume', 'cache'));
      try {
        await d.create(recursive: true);
        return d;
      } catch (_) {}
    }
    return Directory(p.join(dataDir.path, 'cache'));
  }

  DandanplayClient dandanplay() => DandanplayClient(
    appId: settings.value.dandanAppId,
    appSecret: settings.value.dandanAppSecret,
    cacheDir: cacheDir,
  );

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;
  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
