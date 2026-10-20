/// Plug-in interface for content sources.
///
/// A source turns a query into shows, shows into episodes, and an episode
/// into something the player can open. The local library is just one source;
/// legal online sources (your own media server, a Jellyfin/Plex/Emby
/// instance, an official free-to-watch catalogue with a public API, …) can be
/// added later by implementing [MediaSource] and registering it in
/// [SourceRegistry]. For sites without an API there is also a generic,
/// rule-driven web scraper (see sources/web/); Yume ships no site rules and
/// should only be pointed at sources you are allowed to use.
library;

import 'package:flutter/widgets.dart';

class SourceShow {
  const SourceShow({
    required this.sourceId,
    required this.id,
    required this.title,
    this.coverUrl,
    this.synopsis,
    this.extra = const {},
  });

  final String sourceId;

  /// Source-specific opaque id.
  final String id;
  final String title;
  final String? coverUrl;
  final String? synopsis;
  final Map<String, Object?> extra;
}

class SourceEpisode {
  const SourceEpisode({
    required this.id,
    required this.title,
    this.number,
    this.extra = const {},
  });

  final String id;
  final String title;
  final double? number;
  final Map<String, Object?> extra;
}

class SubtitleRef {
  const SubtitleRef({required this.uri, this.title, this.language});
  final String uri;
  final String? title;
  final String? language;
}

/// Everything the player needs to open an episode.
class PlayableMedia {
  const PlayableMedia({
    required this.uri,
    this.httpHeaders = const {},
    this.subtitles = const [],
    this.title,
    this.localPath,
  });

  /// File path or http(s) URL understood by mpv.
  final String uri;
  final Map<String, String> httpHeaders;
  final List<SubtitleRef> subtitles;
  final String? title;

  /// Set for local files; enables hash-based danmaku matching.
  final String? localPath;
}

class SourceCapabilities {
  const SourceCapabilities({this.search = true, this.browse = false});
  final bool search;
  final bool browse;
}

abstract class MediaSource {
  /// Stable machine id, e.g. `local`, `jellyfin`.
  String get id;
  String get name;
  IconData get icon;
  SourceCapabilities get capabilities => const SourceCapabilities();

  /// Called once at startup; load config, check connectivity.
  Future<void> init() async {}

  Future<List<SourceShow>> search(String query);

  /// Optional "browse everything" listing.
  Future<List<SourceShow>> browse() async => const [];

  Future<List<SourceEpisode>> episodes(SourceShow show);

  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode);
}

/// Holds the registered sources. Plug-ins register at startup in main.dart.
class SourceRegistry extends ChangeNotifier {
  final List<MediaSource> _sources = [];
  List<MediaSource> get sources => List.unmodifiable(_sources);

  void register(MediaSource source) {
    if (_sources.any((s) => s.id == source.id)) {
      throw StateError('Source "${source.id}" already registered');
    }
    _sources.add(source);
    notifyListeners();
  }

  void unregister(String id) {
    _sources.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Replaces every source whose id starts with [prefix] with [replacements].
  /// Used to re-load the user's web-source rules after they change.
  void replaceWithPrefix(String prefix, Iterable<MediaSource> replacements) {
    _sources.removeWhere((s) => s.id.startsWith(prefix));
    for (final s in replacements) {
      if (!_sources.any((e) => e.id == s.id)) _sources.add(s);
    }
    notifyListeners();
  }

  MediaSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> initAll() async {
    for (final s in _sources) {
      try {
        await s.init();
      } catch (e) {
        debugPrint('source ${s.id} init failed: $e');
      }
    }
  }
}
