import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../widgets/cover_image.dart';
import 'player_screen.dart';

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class ShowDetailScreen extends StatelessWidget {
  const ShowDetailScreen({super.key, required this.showId});
  final String showId;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.library, app.progress, app.watchlist]),
      builder: (context, _) {
        final show = app.library.byId(showId);
        if (show == null) {
          return const Scaffold(body: Center(child: Text('Show not found')));
        }
        final m = show.metadata;
        final entry = app.watchlist.of(show.id);
        final theme = Theme.of(context);

        EpisodeFile? next;
        final last = app.progress.lastPlayed(show);
        if (last != null && !last.$2.watched) {
          next = last.$1;
        } else {
          next = show.episodes.firstWhere(
            (e) => !(app.progress.of(e.path)?.watched ?? false),
            orElse: () => show.episodes.first,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(show.displayTitle),
            actions: [
              TextButton.icon(
                onPressed: () => _fixMatch(context, show),
                icon: const Icon(Icons.manage_search),
                label: Text(m == null ? 'Find match' : 'Fix match'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 200,
                      height: 290,
                      child: CoverImage(
                        url: m?.coverUrl,
                        fallbackTitle: show.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          show.displayTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (m?.titleNative != null && m!.titleNative != m.title)
                          Text(
                            m.titleNative!,
                            style: theme.textTheme.titleMedium,
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (m?.year != null)
                              Chip(label: Text('${m!.year}')),
                            if (m?.totalEpisodes != null)
                              Chip(label: Text('${m!.totalEpisodes} eps')),
                            if (m?.score != null)
                              Chip(
                                avatar: const Icon(Icons.star, size: 16),
                                label: Text(m!.score!.toStringAsFixed(1)),
                              ),
                            for (final g in m?.genres ?? const <String>[])
                              Chip(label: Text(g)),
                            if (m != null)
                              Chip(
                                label: Text(
                                  'via ${m.provider}${m.anilistId != null ? ' #${m.anilistId}' : ''}${m.bangumiId != null ? ' · bgm #${m.bangumiId}' : ''}',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          m?.synopsis ?? 'No metadata yet. Use “Find match”.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen.local(
                                    show: show,
                                    episode: next!,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: Text(
                                last != null && !last.$2.watched
                                    ? 'Continue ep ${next.episodeKey ?? ''} · ${formatDuration(Duration(milliseconds: last.$2.positionMs))}'
                                    : 'Play ep ${next.episodeKey ?? ''}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<WatchStatus?>(
                              value: entry?.status,
                              hint: const Text('Add to watchlist'),
                              items: [
                                for (final s in WatchStatus.values)
                                  DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label),
                                  ),
                              ],
                              onChanged: (s) {
                                if (s != null) app.watchlist.setStatus(show, s);
                              },
                            ),
                            if (entry != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                'Progress ${entry.progress}/${m?.totalEpisodes ?? '?'}',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Episodes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in show.episodes)
                _EpisodeTile(show: show, episode: e),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fixMatch(BuildContext context, Show show) async {
    final picked = await showDialog<ShowMetadata>(
      context: context,
      builder: (_) => _MatchDialog(initialQuery: show.title),
    );
    if (picked != null && context.mounted) {
      await AppServices.of(context).library.setMatch(show, picked);
    }
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.show, required this.episode});
  final Show show;
  final EpisodeFile episode;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final p = app.progress.of(episode.path);
    final title = show.metadata?.episodeTitles[episode.episodeKey];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(episode.episodeKey ?? '?')),
        title: Text(
          title ?? episode.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                episode.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                if (episode.subtitlePaths.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.subtitles_outlined, size: 16),
                  ),
                if (episode.danmakuPath != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.comment_outlined, size: 16),
                  ),
                if (p != null)
                  Expanded(
                    child: LinearProgressIndicator(
                      value: p.watched ? 1 : p.fraction,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p != null)
              Text(
                p.watched
                    ? 'Watched'
                    : '${formatDuration(Duration(milliseconds: p.positionMs))} / ${formatDuration(Duration(milliseconds: p.durationMs))}',
              ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'restart',
                  child: Text('Play from start'),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear progress'),
                ),
              ],
              onSelected: (v) async {
                if (v == 'clear') {
                  app.progress.clear(episode.path);
                } else {
                  await app.progress.clear(episode.path);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerScreen.local(show: show, episode: episode),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen.local(show: show, episode: episode),
          ),
        ),
      ),
    );
  }
}

class _MatchDialog extends StatefulWidget {
  const _MatchDialog({required this.initialQuery});
  final String initialQuery;

  @override
  State<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends State<_MatchDialog> {
  late final _query = TextEditingController(text: widget.initialQuery);
  String _provider = 'anilist';
  Future<List<ShowMetadata>>? _results;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _results ??= _search();
  }

  Future<List<ShowMetadata>> _search() =>
      AppServices.of(context).metadata.search(_query.text, provider: _provider);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Match show'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onSubmitted: (_) => setState(() => _results = _search()),
                    decoration: const InputDecoration(
                      labelText: 'Search title',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'anilist', label: Text('AniList')),
                    ButtonSegment(value: 'bangumi', label: Text('Bangumi')),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) => setState(() {
                    _provider = s.first;
                    _results = _search();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<ShowMetadata>>(
                future: _results,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return const Center(child: Text('No results'));
                  }
                  return ListView(
                    children: [
                      for (final m in list)
                        ListTile(
                          leading: SizedBox(
                            width: 40,
                            child: CoverImage(
                              url: m.coverUrl,
                              fallbackTitle: '',
                            ),
                          ),
                          title: Text(m.title),
                          subtitle: Text(
                            [
                              m.titleNative,
                              if (m.year != null) '${m.year}',
                              if (m.totalEpisodes != null)
                                '${m.totalEpisodes} eps',
                            ].whereType<String>().join(' · '),
                          ),
                          onTap: () => Navigator.of(context).pop(m),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
