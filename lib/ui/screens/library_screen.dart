import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import 'player_screen.dart';
import 'show_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.library, app.progress]),
      builder: (context, _) {
        final lib = app.library;
        final f = _filter.toLowerCase();
        final shows = lib.shows
            .where(
              (s) =>
                  f.isEmpty ||
                  s.displayTitle.toLowerCase().contains(f) ||
                  s.title.toLowerCase().contains(f) ||
                  (s.metadata?.titleNative?.toLowerCase().contains(f) ?? false),
            )
            .toList();
        final continuing = <(Show, EpisodeFile, PlaybackProgress)>[];
        for (final s in lib.shows) {
          final lp = app.progress.lastPlayed(s);
          if (lp != null && !lp.$2.watched) continuing.add((s, lp.$1, lp.$2));
        }
        continuing.sort((a, b) => b.$3.updatedAt.compareTo(a.$3.updatedAt));

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Library',
                trailing: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Search',
                      ),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Rescan folders',
                    onPressed: lib.scanning ? null : () => lib.rescan(),
                    icon: lib.scanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (lib.status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                  child: Text(
                    lib.status!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: shows.isEmpty
                    ? _EmptyState(
                        scanning: lib.scanning,
                        roots: app.settings.value.libraryPaths,
                      )
                    : CustomScrollView(
                        slivers: [
                          if (continuing.isNotEmpty && f.isEmpty) ...[
                            const _SectionLabel('Continue watching'),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 84,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  itemCount: continuing.length.clamp(0, 10),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (_, i) => _ContinueCard(
                                    show: continuing[i].$1,
                                    episode: continuing[i].$2,
                                    progress: continuing[i].$3,
                                  ),
                                ),
                              ),
                            ),
                            const _SectionLabel('All shows'),
                          ],
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    childAspectRatio: 0.58,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 24,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _ShowCard(show: shows[i]),
                                childCount: shows.length,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
    sliver: SliverToBoxAdapter(
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: Palette.textFaint,
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning, required this.roots});
  final bool scanning;
  final List<String> roots;

  @override
  Widget build(BuildContext context) => Center(
    child: Glass(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, size: 40, color: Palette.textDim),
          const SizedBox(height: 12),
          Text(
            scanning ? 'Scanning…' : 'No videos yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            roots.join('\n'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

/// Poster with title underneath; lifts slightly on hover.
class _ShowCard extends StatefulWidget {
  const _ShowCard({required this.show});
  final Show show;

  @override
  State<_ShowCard> createState() => _ShowCardState();
}

class _ShowCardState extends State<_ShowCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final show = widget.show;
    final watched = show.episodes
        .where((e) => app.progress.of(e.path)?.watched ?? false)
        .length;
    final total = show.metadata?.totalEpisodes ?? show.episodes.length;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShowDetailScreen(showId: show.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: _hover ? 1.03 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hover ? const Color(0x55FFFFFF) : Palette.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(
                          url: show.metadata?.coverUrl,
                          fallbackTitle: show.title,
                        ),
                        if (watched > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ThinProgress(watched / total),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              show.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              watched > 0
                  ? '$watched / $total watched'
                  : '${show.episodes.length} episodes',
              style: const TextStyle(fontSize: 12, color: Palette.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.show,
    required this.episode,
    required this.progress,
  });
  final Show show;
  final EpisodeFile episode;
  final PlaybackProgress progress;

  @override
  Widget build(BuildContext context) {
    final epTitle = show.metadata?.episodeTitles[episode.episodeKey];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen.local(show: show, episode: episode),
          ),
        ),
        child: Glass(
          blur: false,
          radius: 16,
          child: SizedBox(
            width: 300,
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: double.infinity,
                  child: CoverImage(
                    url: show.metadata?.coverUrl,
                    fallbackTitle: '',
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          show.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EP ${episode.episodeKey ?? '?'}${epTitle != null ? ' · $epTitle' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.textFaint,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ThinProgress(progress.fraction),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Icon(Icons.play_arrow_rounded, color: Palette.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
