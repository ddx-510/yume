import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import '../widgets/poster_card.dart';
import 'show_detail_screen.dart';

/// Opens the right page for a catalogue entry: your library's show page if
/// you have the files, otherwise the catalogue page.
void openAnime(BuildContext context, ShowMetadata m) {
  final local = AppServices.of(context).library.matchFor(m);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => local != null
          ? ShowDetailScreen(showId: local.id)
          : AnimeScreen(metadata: m),
    ),
  );
}

/// Catalogue page for an anime that isn't in the local library: details,
/// episode list and watchlist tracking (no playback).
class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key, required this.metadata});
  final ShowMetadata metadata;

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  late ShowMetadata _m = widget.metadata;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  /// Fills in what list endpoints leave out (synopsis, episode titles).
  Future<void> _load() async {
    final meta = AppServices.of(context).metadata;
    try {
      var m = _m;
      if (m.synopsis == null || m.synopsis!.isEmpty) {
        // Opened from a sparse source (schedule, watchlist): fetch details.
        final full = m.anilistId != null
            ? await meta.anilist.byId(m.anilistId!)
            : m.bangumiId != null
            ? await meta.bangumi.byId(m.bangumiId!)
            : null;
        if (full != null) m = full.copyWith(bangumiId: m.bangumiId);
      }
      m = await meta.enrich(m);
      if (mounted) setState(() => _m = m);
    } catch (_) {
      // Keep what the list gave us.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.watchlist, app.library]),
      builder: (context, _) {
        final m = _m;
        final show = app.library.showFor(m);
        final entry = app.watchlist.of(show.id);
        final facts = [
          if (m.year != null) '${m.year}',
          if (m.totalEpisodes != null) '${m.totalEpisodes} episodes',
          if (m.score != null && m.score! > 0)
            '★ ${m.score!.toStringAsFixed(1)}',
          ...m.genres.take(3),
        ];
        final episodes = m.episodeTitles.entries.toList()
          ..sort(
            (a, b) => (double.tryParse(a.key) ?? 0).compareTo(
              double.tryParse(b.key) ?? 0,
            ),
          );
        final link = m.anilistId != null
            ? Uri.parse('https://anilist.co/anime/${m.anilistId}')
            : m.bangumiId != null
            ? Uri.parse('https://bgm.tv/subject/${m.bangumiId}')
            : null;

        return Scaffold(
          backgroundColor: Palette.background,
          body: Stack(
            children: [
              Positioned.fill(child: CoverBackdrop(coverUrl: m.coverUrl)),
              ListView(
                padding: const EdgeInsets.fromLTRB(40, 72, 40, 40),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 190,
                        height: 276,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Palette.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 40,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: CoverImage(
                            url: m.coverUrl,
                            fallbackTitle: m.title,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            if (m.titleNative != null &&
                                m.titleNative != m.title)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  m.titleNative!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Palette.textDim,
                                  ),
                                ),
                              ),
                            if (facts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  facts.join('  ·  '),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Palette.textDim,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                WatchStatusButton(show: show, entry: entry),
                                if (link != null)
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(link),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      m.anilistId != null
                                          ? 'AniList'
                                          : 'Bangumi',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Not in your library. Put the files in a folder named after '
                              'the show inside your library folder and rescan to play it here.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Palette.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (m.synopsis != null && m.synopsis!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Synopsis(m.synopsis!),
                  ],
                  const SizedBox(height: 32),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (episodes.isNotEmpty)
                    Glass(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (var i = 0; i < episodes.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 20,
                                endIndent: 20,
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      episodes[i].key.padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w300,
                                        color:
                                            (entry?.progress ?? 0) >=
                                                (double.tryParse(
                                                      episodes[i].key,
                                                    ) ??
                                                    0)
                                            ? Palette.textFaint
                                            : Palette.text,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      episodes[i].value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              Positioned(
                top: 20,
                left: 24,
                child: Glass(
                  radius: 14,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
