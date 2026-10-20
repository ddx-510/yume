import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'json_store.dart';
import 'library_scanner.dart';
import 'metadata/metadata_service.dart';
import 'settings_service.dart';

/// Owns the local library: scanning, metadata matching and persistence.
class LibraryService extends ChangeNotifier {
  LibraryService(this._store, this._settings, this.metadata);

  final JsonStore _store;
  final SettingsService _settings;
  final MetadataService metadata;
  final _scanner = LibraryScanner();

  List<Show> _shows = [];
  List<Show> get shows => _shows;

  bool scanning = false;
  String? status;
  List<String> missingRoots = [];

  Show? byId(String id) {
    for (final s in _shows) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The local show matching a catalogue entry (same AniList or Bangumi id).
  Show? matchFor(ShowMetadata m) {
    for (final s in _shows) {
      final sm = s.metadata;
      if (sm == null) continue;
      if (m.anilistId != null && sm.anilistId == m.anilistId) return s;
      if (m.bangumiId != null && sm.bangumiId == m.bangumiId) return s;
    }
    return null;
  }

  /// A catalogue entry as a [Show]: the local one if you have the files,
  /// otherwise a file-less stand-in (id `anilist:123` / `bgm:456`) so it can
  /// still go on the watchlist.
  Show showFor(ShowMetadata m) =>
      matchFor(m) ??
      Show(id: remoteId(m), title: m.title, episodes: const [], metadata: m);

  static String remoteId(ShowMetadata m) =>
      m.anilistId != null ? 'anilist:${m.anilistId}' : 'bgm:${m.bangumiId}';

  Future<void> load() async {
    final data = await _store.read();
    if (data is List) {
      _shows = data
          .map((e) => Show.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _save() => _store.write(_shows.map((s) => s.toJson()).toList());

  /// Rescans all library folders, keeps existing metadata for known shows and
  /// fetches metadata for new ones.
  Future<void> rescan({bool refetchMetadata = false}) async {
    if (scanning) return;
    scanning = true;
    status = 'Scanning folders…';
    notifyListeners();
    try {
      final result = await _scanner.scan(_settings.value.libraryPaths);
      missingRoots = result.missingRoots;
      final previous = {for (final s in _shows) s.id: s};
      for (final s in result.shows) {
        final old = previous[s.id];
        if (old != null && !refetchMetadata) {
          s.metadata = old.metadata;
          s.matchLocked = old.matchLocked;
        } else if (old != null && old.matchLocked) {
          s.metadata = old.metadata;
          s.matchLocked = true;
        }
      }
      // Keep shows from unplugged roots so the library doesn't vanish when the
      // external disk is not mounted.
      final kept = _shows.where(
        (s) =>
            !result.shows.any((n) => n.id == s.id) &&
            s.episodes.any(
              (e) => missingRoots.any((r) => e.path.startsWith(r)),
            ),
      );
      _shows = [...result.shows, ...kept];
      notifyListeners();
      await _save();

      final todo = _shows.where((s) => s.metadata == null).toList();
      for (var i = 0; i < todo.length; i++) {
        status = 'Fetching metadata ${i + 1}/${todo.length}: ${todo[i].title}';
        notifyListeners();
        try {
          todo[i].metadata = await metadata.autoMatch(todo[i]);
        } catch (e) {
          debugPrint('metadata failed for ${todo[i].title}: $e');
        }
        notifyListeners();
        // Stay well under AniList's 90 req/min limit.
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      await _save();
      status = missingRoots.isEmpty
          ? null
          : 'Not found: ${missingRoots.join(', ')} (is the disk connected?)';
    } catch (e) {
      status = 'Scan failed: $e';
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> setMatch(Show show, ShowMetadata m) async {
    show.metadata = await metadata.enrich(m);
    show.matchLocked = true;
    notifyListeners();
    await _save();
  }

  Future<void> refreshMetadata(Show show) async {
    show.metadata = await metadata.autoMatch(show);
    show.matchLocked = false;
    notifyListeners();
    await _save();
  }
}
