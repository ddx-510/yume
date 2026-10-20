import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import 'player_screen.dart';

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

void _play(BuildContext context, Show show, EpisodeFile ep) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen.local(show: show, episode: ep),
      ),
    );

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

        EpisodeFile next;
        final last = app.progress.lastPlayed(show);
        final resuming = last != null && !last.$2.watched;
        if (resuming) {
          next = last.$1;
        } else {
          next = show.episodes.firstWhere(
            (e) => !(app.progress.of(e.path)?.watched ?? false),
            orElse: () => show.episodes.first,
          );
        }

        final facts = [
          if (m?.year != null) '${m!.year}',
          if (m?.totalEpisodes != null) '${m!.totalEpisodes} episodes',
          if (m?.score != null) '★ ${m!.score!.toStringAsFixed(1)}',
          ...?m?.genres.take(3),
        ];

        return Scaffold(
          backgroundColor: Palette.background,
          body: Stack(
            children: [
              // Blurred cover as an ambient backdrop.
              Positioned.fill(
                child: Opacity(
                  opacity: 0.45,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: CoverImage(url: m?.coverUrl, fallbackTitle: ''),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66050507), Color(0xF2050507)],
                      stops: [0, 0.6],
                    ),
                  ),
                ),
              ),
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
                            url: m?.coverUrl,
                            fallbackTitle: show.title,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              show.displayTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            if (m?.titleNative != null &&
                                m!.titleNative != m.title)
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
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _play(context, show, next),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(
                                    resuming
                                        ? 'Resume EP ${next.episodeKey ?? ''} · ${formatDuration(Duration(milliseconds: last.$2.positionMs))}'
                                        : 'Play EP ${next.episodeKey ?? ''}',
                                  ),
                                ),
                                _WatchStatusButton(show: show, entry: entry),
                                OutlinedButton(
                                  onPressed: () => _fixMatch(context, show),
                                  child: Text(
                                    m == null ? 'Find match' : 'Fix match',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (m?.synopsis != null) ...[
                    const SizedBox(height: 32),
                    _Synopsis(m!.synopsis!),
                  ],
                  const SizedBox(height: 32),
                  Glass(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        for (var i = 0; i < show.episodes.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, indent: 20, endIndent: 20),
                          _EpisodeRow(show: show, episode: show.episodes[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Floating back button.
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

class _Synopsis extends StatefulWidget {
  const _Synopsis(this.text);
  final String text;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _open = !_open),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Text(
          widget.text,
          maxLines: _open ? null : 3,
          overflow: _open ? null : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Palette.textDim,
          ),
        ),
      ),
    ),
  );
}

class _WatchStatusButton extends StatelessWidget {
  const _WatchStatusButton({required this.show, required this.entry});
  final Show show;
  final WatchEntry? entry;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final total = show.metadata?.totalEpisodes;
    return PopupMenuButton<WatchStatus>(
      tooltip: 'Watchlist',
      position: PopupMenuPosition.under,
      onSelected: (s) => app.watchlist.setStatus(show, s),
      itemBuilder: (_) => [
        for (final s in WatchStatus.values)
          CheckedPopupMenuItem(
            value: s,
            checked: entry?.status == s,
            child: Text(s.label),
          ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: Icon(
            entry == null ? Icons.add_rounded : Icons.bookmark_rounded,
            size: 18,
          ),
          label: Text(
            entry == null
                ? 'Watchlist'
                : '${entry!.status.label} · ${entry!.progress}/${total ?? '?'}',
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.show, required this.episode});
  final Show show;
  final EpisodeFile episode;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final p = app.progress.of(episode.path);
    final title = show.metadata?.episodeTitles[episode.episodeKey];
    final watched = p?.watched ?? false;
    return InkWell(
      onTap: () => _play(context, show, episode),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                episode.episodeKey?.padLeft(2, '0') ?? '–',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: watched ? Palette.textFaint : Palette.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? episode.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: watched ? Palette.textDim : Palette.text,
                    ),
                  ),
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        episode.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.textFaint,
                        ),
                      ),
                    ),
                  if (p != null && !watched)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 24),
                      child: ThinProgress(p.fraction),
                    ),
                ],
              ),
            ),
            if (p != null)
              Text(
                watched
                    ? 'Watched'
                    : formatDuration(Duration(milliseconds: p.positionMs)),
                style: const TextStyle(fontSize: 12, color: Palette.textFaint),
              ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Palette.textFaint,
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restart', child: Text('Play from start')),
                PopupMenuItem(value: 'clear', child: Text('Clear progress')),
              ],
              onSelected: (v) async {
                await app.progress.clear(episode.path);
                if (v == 'restart' && context.mounted) {
                  _play(context, show, episode);
                }
              },
            ),
          ],
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
    return Dialog(
      child: SizedBox(
        width: 560,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match show',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onSubmitted: (_) => setState(() => _results = _search()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Search title',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 36,
                                height: 52,
                                child: CoverImage(
                                  url: m.coverUrl,
                                  fallbackTitle: '',
                                ),
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
                              style: const TextStyle(color: Palette.textFaint),
                            ),
                            onTap: () => Navigator.of(context).pop(m),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
