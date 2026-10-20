import '../../models/models.dart';
import '../../util/filename_parser.dart';
import '../settings_service.dart';
import 'anilist_client.dart';
import 'bangumi_client.dart';

/// Picks a metadata match for a show and enriches it with episode titles.
class MetadataService {
  MetadataService(
    this._settings, {
    AniListClient? anilist,
    BangumiClient? bangumi,
  }) : anilist = anilist ?? AniListClient(),
       bangumi = bangumi ?? BangumiClient();

  final SettingsService _settings;
  final AniListClient anilist;
  final BangumiClient bangumi;

  /// Search candidates for the manual "fix match" dialog.
  Future<List<ShowMetadata>> search(String query, {String? provider}) {
    final p = provider ?? _settings.value.metadataProvider;
    return p == 'bangumi' ? bangumi.search(query) : anilist.search(query);
  }

  /// Automatic match: best search hit by title similarity.
  Future<ShowMetadata?> autoMatch(Show show) async {
    final query = show.title;
    final provider = _settings.value.metadataProvider;
    List<ShowMetadata> hits;
    try {
      hits = await search(query, provider: provider);
      if (hits.isEmpty && searchableTitle(query) != query) {
        hits = await search(searchableTitle(query), provider: provider);
      }
    } catch (_) {
      // Fall back to the other provider if the primary one is down.
      hits = await search(
        query,
        provider: provider == 'bangumi' ? 'anilist' : 'bangumi',
      );
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) => _score(b, show).compareTo(_score(a, show)));
    return enrich(hits.first);
  }

  double _score(ShowMetadata m, Show show) {
    final target = normalizeTitle(show.title);
    final names = [
      m.title,
      m.titleEnglish,
      m.titleNative,
    ].whereType<String>().map(normalizeTitle).where((s) => s.isNotEmpty);
    var best = 0.0;
    for (final n in names) {
      best = best < _similarity(n, target) ? _similarity(n, target) : best;
    }
    // Prefer entries with enough episodes for the files we have.
    final maxEp = show.episodes
        .map((e) => e.episode ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (m.totalEpisodes != null && maxEp > m.totalEpisodes!) best -= 0.2;
    return best;
  }

  /// Fills in episode titles/ids from Bangumi (and Bangumi id for AniList hits).
  Future<ShowMetadata> enrich(ShowMetadata m) async {
    if (!_settings.value.fetchBangumiEpisodes) return m;
    try {
      var bgmId = m.bangumiId;
      String? nativeTitle = m.titleNative;
      String? synopsisCn;
      if (bgmId == null) {
        final q = m.titleNative ?? m.title;
        final hits = await bangumi.search(q, limit: 5);
        if (hits.isNotEmpty) {
          final want = normalizeTitle(q);
          hits.sort(
            (a, b) =>
                _similarity(
                  normalizeTitle(b.titleNative ?? b.title),
                  want,
                ).compareTo(
                  _similarity(normalizeTitle(a.titleNative ?? a.title), want),
                ),
          );
          final best = hits.first;
          if (_similarity(
                normalizeTitle(best.titleNative ?? best.title),
                want,
              ) >
              0.5) {
            bgmId = best.bangumiId;
            synopsisCn = best.synopsis;
          }
        }
      }
      if (bgmId == null) return m;
      final (titles, ids) = await bangumi.episodes(bgmId);
      return m.copyWith(
        bangumiId: bgmId,
        episodeTitles: titles,
        bangumiEpisodeIds: ids,
        titleNative: nativeTitle,
        synopsis: (m.synopsis == null || m.synopsis!.isEmpty)
            ? synopsisCn
            : null,
      );
    } catch (_) {
      return m;
    }
  }
}

/// Dice coefficient on character bigrams (works for CJK and Latin titles).
double _similarity(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  if (a.contains(b) || b.contains(a)) return 0.9;
  Set<String> grams(String s) {
    final t = s.replaceAll(' ', '');
    return {for (var i = 0; i < t.length - 1; i++) t.substring(i, i + 2)};
  }

  final ga = grams(a), gb = grams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  return 2 * ga.intersection(gb).length / (ga.length + gb.length);
}
