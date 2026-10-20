import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../services/library_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/poster_card.dart';
import 'anime_screen.dart';

enum _Mode {
  trending('Trending'),
  season('This season'),
  schedule('Schedule'),
  popular('All-time popular'),
  search('Results');

  const _Mode(this.label);
  final String label;
}

/// Kazumi-style catalogue: trending, current season, weekly schedule and
/// search, from AniList and Bangumi. Metadata only; playback still comes
/// from your library or a source plug-in.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  _Mode _mode = _Mode.trending;
  int _weekday = DateTime.now().weekday;
  String _query = '';
  final _search = TextEditingController();

  // Loaded once per app run; switching tabs doesn't refetch.
  final _cache = <_Mode, Future<List<ShowMetadata>>>{};
  Future<List<ShowMetadata>>? _searchResults;
  Future<Map<int, List<ShowMetadata>>>? _calendar;

  static (String, int) _currentSeason() {
    final now = DateTime.now();
    const seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
    return (seasons[(now.month - 1) ~/ 3], now.year);
  }

  Future<List<ShowMetadata>> _load(_Mode mode) {
    final meta = AppServices.of(context).metadata;
    if (mode == _Mode.search) {
      return _searchResults ??= meta.search(_query);
    }
    return _cache.putIfAbsent(mode, () {
      final f = switch (mode) {
        _Mode.season => () {
          final (season, year) = _currentSeason();
          return meta.anilist.browse(
            sort: 'POPULARITY_DESC',
            season: season,
            year: year,
          );
        }(),
        _Mode.popular => meta.anilist.browse(sort: 'POPULARITY_DESC'),
        _ => meta.anilist.browse(sort: 'TRENDING_DESC'),
      };
      // Don't cache failures, so a retry actually retries.
      return f.catchError((Object e) {
        _cache.remove(mode);
        throw e;
      });
    });
  }

  void _runSearch() {
    final q = _search.text.trim();
    setState(() {
      if (q.isEmpty) {
        _mode = _Mode.trending;
      } else {
        _query = q;
        _searchResults = null;
        _mode = _Mode.search;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final (season, year) = _currentSeason();
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Discover',
            trailing: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    hintText: 'Search any anime',
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: Row(
              children: [
                for (final m in _Mode.values)
                  if (m != _Mode.search || _mode == _Mode.search)
                    GlassPill(
                      label: m == _Mode.season
                          ? '${season[0]}${season.substring(1).toLowerCase()} $year'
                          : m == _Mode.search
                          ? '“$_query”'
                          : m.label,
                      selected: m == _mode,
                      onTap: () => setState(() => _mode = m),
                    ),
              ],
            ),
          ),
          Expanded(
            child: _mode == _Mode.schedule ? _schedule() : _grid(_load(_mode)),
          ),
        ],
      ),
    );
  }

  Widget _schedule() {
    _calendar ??= AppServices.of(context).metadata.bangumi.calendar()
      ..catchError((Object _) {
        _calendar = null;
        return <int, List<ShowMetadata>>{};
      });
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: Row(
            children: [
              for (var d = 1; d <= 7; d++)
                GlassPill(
                  label: d == today ? 'Today' : days[d - 1],
                  selected: d == _weekday,
                  onTap: () => setState(() => _weekday = d),
                ),
            ],
          ),
        ),
        Expanded(
          child: _grid(
            _calendar!.then((c) => c[_weekday] ?? const <ShowMetadata>[]),
            subtitle: (m) => m.score != null && m.score! > 0
                ? '★ ${m.score!.toStringAsFixed(1)}'
                : 'Airing',
          ),
        ),
      ],
    );
  }

  Widget _grid(
    Future<List<ShowMetadata>> future, {
    String Function(ShowMetadata)? subtitle,
  }) {
    final app = AppServices.of(context);
    return FutureBuilder<List<ShowMetadata>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Palette.textFaint),
                const SizedBox(height: 8),
                Text(
                  'Couldn’t load: ${snap.error}',
                  style: const TextStyle(color: Palette.textFaint),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'Nothing here',
              style: TextStyle(color: Palette.textFaint),
            ),
          );
        }
        return ListenableBuilder(
          listenable: Listenable.merge([app.library, app.watchlist]),
          builder: (context, _) => GridView.builder(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
            gridDelegate: posterGridDelegate,
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i];
              final local = app.library.matchFor(m);
              final entry = app.watchlist.of(
                local?.id ?? LibraryService.remoteId(m),
              );
              final total = m.totalEpisodes;
              return PosterCard(
                coverUrl: m.coverUrl,
                title: m.title,
                subtitle:
                    subtitle?.call(m) ??
                    [
                      if (m.year != null) '${m.year}',
                      if (total != null) '$total eps',
                      if (m.score != null) '★ ${m.score!.toStringAsFixed(1)}',
                    ].join(' · '),
                badge: local != null ? 'In library' : entry?.status.label,
                progress: entry != null && total != null && total > 0
                    ? entry.progress / total
                    : null,
                onTap: () => openAnime(context, m),
              );
            },
          ),
        );
      },
    );
  }
}
