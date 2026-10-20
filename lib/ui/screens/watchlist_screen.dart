import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import 'anime_screen.dart';
import 'show_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  WatchStatus _status = WatchStatus.watching;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.watchlist, app.settings]),
      builder: (context, _) {
        final wl = app.watchlist;
        final connected = wl.trackers
            .where((t) => t.isConnected)
            .map((t) => t.name)
            .toList();
        final entries = wl.entries.where((e) => e.status == _status).toList();
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Watchlist',
                trailing: [
                  Tooltip(
                    message: connected.isEmpty
                        ? 'Connect AniList or Bangumi in Settings to sync'
                        : 'Push everything to ${connected.join(' + ')}',
                    child: TextButton.icon(
                      onPressed: wl.syncing || connected.isEmpty
                          ? null
                          : () => wl.sync(all: true),
                      icon: wl.syncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              connected.isEmpty
                                  ? Icons.cloud_off_rounded
                                  : Icons.sync_rounded,
                              size: 18,
                            ),
                      label: Text(
                        connected.isEmpty ? 'Local only' : 'Sync',
                        style: const TextStyle(color: Palette.textDim),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in WatchStatus.values)
                        GlassPill(
                          label:
                              '${s.label}  ${wl.entries.where((e) => e.status == s).length}',
                          selected: s == _status,
                          onTap: () => setState(() => _status = s),
                        ),
                    ],
                  ),
                ),
              ),
              if (wl.lastSyncMessage != null && connected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                  child: Text(
                    wl.lastSyncMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'Nothing here yet',
                          style: TextStyle(color: Palette.textFaint),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _EntryRow(entry: entries[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final WatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    final e = entry;
    final show = app.library.byId(e.showId);
    final meta = ShowMetadata(
      provider: e.anilistId != null ? 'anilist' : 'bangumi',
      anilistId: e.anilistId,
      bangumiId: e.bangumiId,
      title: e.title,
      coverUrl: e.coverUrl,
      totalEpisodes: e.totalEpisodes,
    );
    // File-less stand-in for shows tracked from Discover.
    final target = show ?? app.library.showFor(meta);
    final total = e.totalEpisodes;
    return Glass(
      blur: false,
      radius: 16,
      child: InkWell(
        onTap: () => show != null
            ? Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShowDetailScreen(showId: show.id),
                ),
              )
            : openAnime(context, meta),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 62,
                  child: CoverImage(url: e.coverUrl, fallbackTitle: ''),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.lastSyncError != null
                          ? 'Sync failed — ${e.lastSyncError}'
                          : '${e.progress} / ${total ?? '?'} episodes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: e.lastSyncError != null
                            ? const Color(0xFFFF8A8A)
                            : Palette.textFaint,
                      ),
                    ),
                    if (total != null && total > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 40),
                        child: ThinProgress(e.progress / total),
                      ),
                  ],
                ),
              ),
              ...[
                IconButton(
                  tooltip: '−1 episode',
                  onPressed: e.progress > 0
                      ? () => app.watchlist.setProgress(target, e.progress - 1)
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                ),
                IconButton(
                  tooltip: '+1 episode',
                  onPressed: () =>
                      app.watchlist.setProgress(target, e.progress + 1),
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ],
              IconButton(
                tooltip: 'Remove',
                onPressed: () => app.watchlist.remove(e.showId),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Palette.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
