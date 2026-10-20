import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../sources/media_source.dart';
import '../widgets/cover_image.dart';
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
    final registry = AppServices.of(context).sources;
    final sources = registry.sources;
    _selected ??= sources.isEmpty ? null : sources.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Sources')),
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: ListView(
              children: [
                for (final s in sources)
                  ListTile(
                    leading: Icon(s.icon),
                    title: Text(s.name),
                    subtitle: Text(s.id),
                    selected: s == _selected,
                    onTap: () => setState(() {
                      _selected = s;
                      _results = null;
                    }),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add legal sources by implementing MediaSource '
                    '(lib/sources/media_source.dart) and registering them in '
                    'lib/app_services.dart. See docs/PLUGINS.md.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected == null
                ? const Center(child: Text('No sources registered'))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _query,
                                decoration: InputDecoration(
                                  labelText: _selected!.id == 'url'
                                      ? 'Paste an http(s) video URL'
                                      : 'Search ${_selected!.name}',
                                  border: const OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _search(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _search,
                              child: const Text('Go'),
                            ),
                            if (_selected!.capabilities.browse) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => setState(
                                  () => _results = _selected!.browse(),
                                ),
                                child: const Text('Browse all'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _resultsView()),
                      ],
                    ),
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
        if (snap.hasError) return Text('Error: ${snap.error}');
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('No results'));
        return ListView(
          children: [
            for (final show in list)
              ExpansionTile(
                leading: SizedBox(
                  width: 36,
                  child: CoverImage(url: show.coverUrl, fallbackTitle: ''),
                ),
                title: Text(show.title),
                children: [
                  FutureBuilder<List<SourceEpisode>>(
                    future: _selected!.episodes(show),
                    builder: (context, eps) {
                      if (!eps.hasData) return const LinearProgressIndicator();
                      return Column(
                        children: [
                          for (final e in eps.data!)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.play_circle_outline),
                              title: Text(e.title),
                              onTap: () async {
                                final media = await _selected!.resolve(show, e);
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PlayerScreen.media(media: media),
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
          ],
        );
      },
    );
  }
}
