import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../widgets/cover_image.dart';
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
          if (lp != null) continuing.add((s, lp.$1, lp.$2));
        }
        continuing.sort((a, b) => b.$3.updatedAt.compareTo(a.$3.updatedAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Library'),
            actions: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rescan folders',
                onPressed: lib.scanning ? null : () => lib.rescan(),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lib.scanning) const LinearProgressIndicator(),
              if (lib.status != null)
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(lib.status!),
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
                            const SliverPadding(
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                              sliver: SliverToBoxAdapter(
                                child: Text('Continue watching'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 92,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  children: [
                                    for (final c in continuing.take(10))
                                      _ContinueCard(
                                        show: c.$1,
                                        episode: c.$2,
                                        progress: c.$3,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 190,
                                    childAspectRatio: 0.56,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scanning, required this.roots});
  final bool scanning;
  final List<String> roots;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_filter_outlined, size: 64),
          const SizedBox(height: 12),
          Text(scanning ? 'Scanning…' : 'No videos found'),
          const SizedBox(height: 8),
          Text(
            'Library folders: ${roots.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Change them in Settings. Use one folder per show for best matching.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final watched = show.episodes
        .where((e) => app.progress.of(e.path)?.watched ?? false)
        .length;
    final total = show.metadata?.totalEpisodes ?? show.episodes.length;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShowDetailScreen(showId: show.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(
                    url: show.metadata?.coverUrl,
                    fallbackTitle: show.title,
                  ),
                  if (show.metadata == null)
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: Tooltip(
                        message: 'No metadata match yet',
                        child: Icon(Icons.help_outline, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            show.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '${show.episodes.length} files · $watched/$total watched',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerScreen.local(show: show, episode: episode),
            ),
          ),
          child: SizedBox(
            width: 280,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: CoverImage(
                    url: show.metadata?.coverUrl,
                    fallbackTitle: '',
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          show.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Episode ${episode.episodeKey ?? '?'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress.fraction),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.play_arrow),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
