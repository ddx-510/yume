import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../widgets/cover_image.dart';
import 'show_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

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
        return DefaultTabController(
          length: WatchStatus.values.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Watchlist'),
              actions: [
                Center(
                  child: Text(
                    connected.isEmpty
                        ? 'Local only (connect AniList/Bangumi in Settings)'
                        : 'Syncing to ${connected.join(' + ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Push all to trackers',
                  onPressed: wl.syncing || connected.isEmpty
                      ? null
                      : () => wl.sync(all: true),
                  icon: wl.syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  for (final s in WatchStatus.values)
                    Tab(
                      text:
                          '${s.label} (${wl.entries.where((e) => e.status == s).length})',
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                if (wl.lastSyncMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      wl.lastSyncMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final s in WatchStatus.values)
                        _EntryList(
                          entries: wl.entries
                              .where((e) => e.status == s)
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});
  final List<WatchEntry> entries;

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    if (entries.isEmpty) {
      return const Center(
        child: Text('Nothing here. Add shows from their detail page.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final show = app.library.byId(e.showId);
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 40,
              child: CoverImage(url: e.coverUrl, fallbackTitle: ''),
            ),
            title: Text(e.title),
            subtitle: Text(
              [
                'Progress ${e.progress}/${e.totalEpisodes ?? '?'}',
                if (e.anilistId != null) 'AniList #${e.anilistId}',
                if (e.bangumiId != null) 'Bangumi #${e.bangumiId}',
                if (e.lastSyncError != null)
                  '⚠ ${e.lastSyncError}'
                else if (e.lastSyncedAt != null)
                  'synced',
                if (show == null) 'not in local library',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (show != null) ...[
                  IconButton(
                    tooltip: '-1 episode',
                    onPressed: e.progress > 0
                        ? () => app.watchlist.setProgress(show, e.progress - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: '+1 episode',
                    onPressed: () =>
                        app.watchlist.setProgress(show, e.progress + 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => app.watchlist.remove(e.showId),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            onTap: show == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShowDetailScreen(showId: show.id),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
