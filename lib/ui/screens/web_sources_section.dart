import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Settings block for managing user-supplied web-source rules (the scraper
/// engine). Yume ships no rules; the user imports or pastes their own.
class WebSourcesSection extends StatelessWidget {
  const WebSourcesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: app.ruleStore,
      builder: (context, _) {
        final store = app.ruleStore;
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'WEB SOURCES (SCRAPER)',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Palette.textFaint,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Glass(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a source by importing a rule file (JSON) that describes '
                        'how to search a site, list episodes and find the stream. '
                        'Yume ships none — point it only at sources you’re allowed to '
                        'use. Format: docs/PLUGINS.md.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Palette.textFaint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (store.rules.isEmpty && store.errors.isEmpty)
                        const Text(
                          'No rules loaded.',
                          style: TextStyle(color: Palette.textFaint),
                        ),
                      for (final r in store.rules)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                size: 18,
                                color: Palette.textDim,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name),
                                    Text(
                                      r.baseUrl,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Palette.textFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Palette.textFaint,
                                ),
                                onPressed: () => store.remove(r.rawId),
                              ),
                            ],
                          ),
                        ),
                      for (final e in store.errors.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '⚠ ${e.key}: ${e.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF8A8A),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.file_open_rounded, size: 18),
                            label: const Text('Import rule file'),
                            onPressed: () => _import(context),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Import from URL'),
                            onPressed: () => _importUrl(context),
                          ),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 18,
                            ),
                            label: const Text('Paste JSON'),
                            onPressed: () => _paste(context),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reload'),
                            onPressed: store.load,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importUrl(BuildContext context) async {
    final app = AppServices.of(context);
    final controller = TextEditingController(
      text: app.settings.value.ruleRepoUrl,
    );
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A URL returning a rule, a list of rules, or an index '
              '{"rules":[{"url":…}]}. In Yume’s own JSON format — point it '
              'only at a source you’re allowed to use.',
              style: TextStyle(fontSize: 12, color: Palette.textFaint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'https://…'),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Fetch'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await app.settings.update((s) => s.copyWith(ruleRepoUrl: url.trim()));
    messenger.showSnackBar(const SnackBar(content: Text('Fetching rules…')));
    try {
      final result = await app.ruleStore.importFromUrl(url.trim());
      messenger.showSnackBar(SnackBar(content: Text(result.summary)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final store = AppServices.of(context).ruleStore;
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'rule', extensions: ['json']),
      ],
    );
    if (file == null) return;
    try {
      final ids = await store.addFromJson(await file.readAsString());
      messenger.showSnackBar(
        SnackBar(content: Text('Added source(s): ${ids.join(', ')}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Invalid rule: $e')));
    }
  }

  Future<void> _paste(BuildContext context) async {
    final store = AppServices.of(context).ruleStore;
    final controller = TextEditingController();
    final jsonText = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 560,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste rule JSON',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 14,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '{ "id": "...", "name": "...", ... }',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (jsonText == null || jsonText.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ids = await store.addFromJson(jsonText);
      messenger.showSnackBar(
        SnackBar(content: Text('Added source(s): ${ids.join(', ')}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Invalid rule: $e')));
    }
  }
}
