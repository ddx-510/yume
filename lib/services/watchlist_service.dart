import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'json_store.dart';
import 'library_service.dart';
import 'settings_service.dart';
import 'sync/trackers.dart';

/// Local watchlist (always works offline) plus push-sync to AniList/Bangumi.
class WatchlistService extends ChangeNotifier {
  WatchlistService(this._store, this._settings, this._library, this.trackers);

  final JsonStore _store;
  final SettingsService _settings;
  final LibraryService _library;
  final List<Tracker> trackers;
  final Map<String, WatchEntry> _entries = {};

  bool syncing = false;
  String? lastSyncMessage;

  List<WatchEntry> get entries =>
      _entries.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  WatchEntry? of(String showId) => _entries[showId];

  Future<void> load() async {
    final data = await _store.read();
    if (data is List) {
      for (final e in data) {
        final entry = WatchEntry.fromJson((e as Map).cast<String, dynamic>());
        _entries[entry.showId] = entry;
      }
    }
    notifyListeners();
  }

  Future<void> _save() =>
      _store.write(_entries.values.map((e) => e.toJson()).toList());

  WatchEntry _ensure(Show show) =>
      _entries.putIfAbsent(
          show.id,
          () => WatchEntry(showId: show.id, title: show.displayTitle),
        )
        ..title = show.displayTitle
        ..anilistId = show.metadata?.anilistId
        ..bangumiId = show.metadata?.bangumiId
        ..coverUrl = show.metadata?.coverUrl
        ..totalEpisodes = show.metadata?.totalEpisodes;

  Future<void> setStatus(Show show, WatchStatus status) async {
    final e = _ensure(show)
      ..status = status
      ..updatedAt = DateTime.now();
    if (status == WatchStatus.completed && e.totalEpisodes != null) {
      e.progress = e.totalEpisodes!;
    }
    await _changed();
  }

  Future<void> setProgress(Show show, int progress) async {
    final e = _ensure(show)
      ..progress = progress
      ..updatedAt = DateTime.now();
    if (e.totalEpisodes != null && progress >= e.totalEpisodes!) {
      e.status = WatchStatus.completed;
    } else if (e.status == WatchStatus.planning ||
        e.status == WatchStatus.completed) {
      e.status = WatchStatus.watching;
    }
    await _changed();
  }

  Future<void> remove(String showId) async {
    _entries.remove(showId);
    notifyListeners();
    await _save();
  }

  /// Called by the player when an episode crosses the "watched" threshold.
  Future<void> onEpisodeWatched(Show show, EpisodeFile ep) async {
    final n = ep.episode?.floor();
    if (n == null || ep.episode! % 1 != 0) return; // skip specials like 7.5
    final current = _entries[show.id]?.progress ?? 0;
    if (n <= current) return;
    await setProgress(show, n);
  }

  Future<void> _changed() async {
    notifyListeners();
    await _save();
    if (_settings.value.autoSync) await sync();
  }

  /// Pushes all changed entries to every connected tracker.
  Future<void> sync({bool all = false}) async {
    final connected = trackers.where((t) => t.isConnected).toList();
    if (connected.isEmpty) {
      lastSyncMessage =
          'No tracker connected — progress is saved locally only.';
      notifyListeners();
      return;
    }
    if (syncing) return;
    syncing = true;
    notifyListeners();
    var pushed = 0, failed = 0;
    for (final e in _entries.values.where((e) => all || e.needsSync).toList()) {
      final show = _library.byId(e.showId);
      final errors = <String>[];
      for (final t in connected) {
        try {
          if (await t.push(e, show)) pushed++;
        } catch (err) {
          errors.add('${t.name}: $err');
        }
      }
      if (errors.isEmpty) {
        e.lastSyncedAt = DateTime.now();
        e.lastSyncError = null;
      } else {
        failed++;
        e.lastSyncError = errors.join('\n');
      }
    }
    syncing = false;
    lastSyncMessage = failed == 0
        ? 'Synced ($pushed updates) at ${_hhmm(DateTime.now())}'
        : '$failed entries failed to sync — see entry details.';
    notifyListeners();
    await _save();
  }
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
