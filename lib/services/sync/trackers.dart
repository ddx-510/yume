import '../../models/models.dart';
import '../metadata/anilist_client.dart';
import '../metadata/bangumi_client.dart';
import '../settings_service.dart';

/// A remote list service the local watchlist can push progress to.
abstract class Tracker {
  String get id;
  String get name;
  bool get isConnected;

  /// Pushes one entry. Throws on failure; returns false if the entry has no
  /// id for this tracker (nothing to do).
  Future<bool> push(WatchEntry entry, Show? show);

  /// Verifies the stored token, returning the account name.
  Future<String> whoAmI();
}

class AniListTracker implements Tracker {
  AniListTracker(this._settings, this._client);
  final SettingsService _settings;
  final AniListClient _client;

  @override
  String get id => 'anilist';
  @override
  String get name => 'AniList';
  @override
  bool get isConnected => _settings.value.anilistToken.isNotEmpty;

  @override
  Future<String> whoAmI() => _client.viewerName(_settings.value.anilistToken);

  @override
  Future<bool> push(WatchEntry entry, Show? show) async {
    final mediaId = entry.anilistId ?? show?.metadata?.anilistId;
    if (mediaId == null) return false;
    await _client.saveProgress(
      token: _settings.value.anilistToken,
      mediaId: mediaId,
      progress: entry.progress,
      status: entry.status,
    );
    return true;
  }
}

class BangumiTracker implements Tracker {
  BangumiTracker(this._settings, this._client);
  final SettingsService _settings;
  final BangumiClient _client;

  @override
  String get id => 'bangumi';
  @override
  String get name => 'Bangumi';
  @override
  bool get isConnected => _settings.value.bangumiToken.isNotEmpty;

  @override
  Future<String> whoAmI() => _client.me(_settings.value.bangumiToken);

  @override
  Future<bool> push(WatchEntry entry, Show? show) async {
    final subjectId = entry.bangumiId ?? show?.metadata?.bangumiId;
    if (subjectId == null) return false;
    final token = _settings.value.bangumiToken;
    await _client.setCollection(token, subjectId, entry.status);
    final ids = show?.metadata?.bangumiEpisodeIds ?? const {};
    final watched = <int>[
      for (var ep = 1; ep <= entry.progress; ep++)
        if (ids['$ep'] != null) ids['$ep']!,
    ];
    await _client.markEpisodesWatched(token, subjectId, watched);
    return true;
  }
}
