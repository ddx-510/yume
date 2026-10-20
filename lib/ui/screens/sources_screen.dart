import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../sources/media_source.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import 'player_screen.dart';

/// Lists registered source plug-ins and lets you search/play through them.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  MediaSource? _selected;
  final _query = TextEditingController();
  Future<List<SourceShow>>? _results;

  @override
  Widget build(BuildContext context) {
    final sources = AppServices.of(context).sources.sources;
    _selected ??= sources.isEmpty ? null : sources.first;
    final sel = _selected;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Sources'),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: Row(
              children: [
                for (final s in sources)
                  GlassPill(
                    label: s.name,
                    selected: s == sel,
                    onTap: () => setState(() {
                      _selected = s;
                      _results = null;
                      _query.clear();
                    }),
                  ),
              ],
            ),
          ),
          if (sel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      decoration: InputDecoration(
                        prefixIcon: Icon(sel.icon, size: 18),
                        hintText: sel.id == 'url'
                            ? 'Paste an http(s) video URL'
                            : 'Search ${sel.name}',
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _search, child: const Text('Go')),
                  if (sel.capabilities.browse) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => setState(() => _results = sel.browse()),
                      child: const Text('Browse'),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(child: _resultsView()),
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 20),
            child: Text(
              'Add legal sources by implementing MediaSource — see docs/PLUGINS.md',
              style: TextStyle(fontSize: 12, color: Palette.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  void _search() => setState(() => _results = _selected!.search(_query.text));

  Widget _resultsView() {
    if (_results == null) return const SizedBox();
    return FutureBuilder<List<SourceShow>>(
      future: _results,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No results',
              style: TextStyle(color: Palette.textFaint),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _SourceShowTile(source: _selected!, show: list[i]),
        );
      },
    );
  }
}

class _SourceShowTile extends StatelessWidget {
  const _SourceShowTile({required this.source, required this.show});
  final MediaSource source;
  final SourceShow show;

  @override
  Widget build(BuildContext context) => Glass(
    blur: false,
    radius: 16,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: Palette.textDim,
        collapsedIconColor: Palette.textFaint,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 32,
            height: 46,
            child: CoverImage(url: show.coverUrl, fallbackTitle: ''),
          ),
        ),
        title: Text(
          show.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [
          FutureBuilder<List<SourceEpisode>>(
            future: source.episodes(show),
            builder: (context, eps) {
              if (!eps.hasData) return const LinearProgressIndicator();
              return Column(
                children: [
                  for (final e in eps.data!)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.play_arrow_rounded),
                      title: Text(e.title),
                      onTap: () async {
                        final media = await source.resolve(show, e);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen.media(media: media),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
