import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../services/metadata/anilist_client.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppServices.of(context);
    return ListenableBuilder(
      listenable: app.settings,
      builder: (context, _) {
        final s = app.settings.value;
        Future<void> set(AppSettings Function(AppSettings) f) =>
            app.settings.update(f);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              const _Header('Library folders'),
              for (final path in s.libraryPaths)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(path),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => set(
                      (v) => v.copyWith(
                        libraryPaths: v.libraryPaths
                            .where((x) => x != path)
                            .toList(),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add folder…'),
                    onPressed: () async {
                      final dir = await getDirectoryPath(
                        initialDirectory: '/Volumes',
                      );
                      if (dir != null && !s.libraryPaths.contains(dir)) {
                        await set(
                          (v) => v.copyWith(
                            libraryPaths: [...v.libraryPaths, dir],
                          ),
                        );
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rescan now'),
                    onPressed: () => app.library.rescan(),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Re-fetch all metadata'),
                    onPressed: () => app.library.rescan(refetchMetadata: true),
                  ),
                ],
              ),
              _TextSetting(
                label: 'Cache folder (covers, danmaku). Empty = <first library>/.yume/cache',
                value: s.cacheDir,
                onSaved: (v) => set((x) => x.copyWith(cacheDir: v)),
              ),

              const _Header('Metadata'),
              ListTile(
                title: const Text('Primary metadata provider'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'anilist', label: Text('AniList')),
                    ButtonSegment(value: 'bangumi', label: Text('Bangumi')),
                  ],
                  selected: {s.metadataProvider},
                  onSelectionChanged: (v) =>
                      set((x) => x.copyWith(metadataProvider: v.first)),
                ),
              ),
              SwitchListTile(
                title: const Text('Fetch episode titles from Bangumi'),
                value: s.fetchBangumiEpisodes,
                onChanged: (v) =>
                    set((x) => x.copyWith(fetchBangumiEpisodes: v)),
              ),

              const _Header('Danmaku'),
              SwitchListTile(
                title: const Text('Show danmaku'),
                value: s.danmakuEnabled,
                onChanged: (v) => set((x) => x.copyWith(danmakuEnabled: v)),
              ),
              _SliderSetting(
                'Opacity',
                s.danmakuOpacity,
                0.2,
                1,
                (v) => set((x) => x.copyWith(danmakuOpacity: v)),
              ),
              _SliderSetting(
                'Font size',
                s.danmakuFontSize,
                14,
                40,
                (v) => set((x) => x.copyWith(danmakuFontSize: v)),
                digits: 0,
              ),
              _SliderSetting(
                'Screen area',
                s.danmakuArea,
                0.2,
                1,
                (v) => set((x) => x.copyWith(danmakuArea: v)),
              ),
              _SliderSetting(
                'Scroll time (s)',
                s.danmakuDurationSec,
                4,
                16,
                (v) => set((x) => x.copyWith(danmakuDurationSec: v)),
                digits: 0,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Online danmaku comes from DanDanPlay (弹弹play), which needs an AppId/AppSecret. '
                  'Apply at https://doc.dandanplay.com/open/. Without it, a Bilibili-format '
                  '<video name>.xml next to the video is used.',
                ),
              ),
              _TextSetting(
                label: 'DanDanPlay AppId',
                value: s.dandanAppId,
                onSaved: (v) => set((x) => x.copyWith(dandanAppId: v)),
              ),
              _TextSetting(
                label: 'DanDanPlay AppSecret',
                value: s.dandanAppSecret,
                obscure: true,
                onSaved: (v) => set((x) => x.copyWith(dandanAppSecret: v)),
              ),

              const _Header('Tracking'),
              SwitchListTile(
                title: const Text('Auto-sync watchlist changes'),
                value: s.autoSync,
                onChanged: (v) => set((x) => x.copyWith(autoSync: v)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'AniList: create an API client at https://anilist.co/settings/developer with redirect URL '
                  'https://anilist.co/api/v2/oauth/pin, paste its Client ID, click Authorize, then paste the token shown.',
                ),
              ),
              _TextSetting(
                label: 'AniList Client ID',
                value: s.anilistClientId,
                onSaved: (v) => set((x) => x.copyWith(anilistClientId: v)),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: s.anilistClientId.isEmpty
                        ? null
                        : () => launchUrl(
                            AniListClient.authorizeUrl(s.anilistClientId),
                          ),
                    child: const Text('Authorize in browser'),
                  ),
                ],
              ),
              _TextSetting(
                label: 'AniList access token',
                value: s.anilistToken,
                obscure: true,
                onSaved: (v) => set((x) => x.copyWith(anilistToken: v)),
              ),
              _TrackerCheck(trackerId: 'anilist'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Bangumi: create a personal access token at https://next.bgm.tv/demo/access-token.',
                ),
              ),
              _TextSetting(
                label: 'Bangumi access token',
                value: s.bangumiToken,
                obscure: true,
                onSaved: (v) => set((x) => x.copyWith(bangumiToken: v)),
              ),
              _TrackerCheck(trackerId: 'bangumi'),
              const SizedBox(height: 24),
              Text(
                'Data: ${app.dataDir.path}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting(
    this.label,
    this.value,
    this.min,
    this.max,
    this.onChanged, {
    this.digits = 2,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final int digits;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: SizedBox(
      width: 320,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text(value.toStringAsFixed(digits))),
        ],
      ),
    ),
  );
}

class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onSaved,
    this.obscure = false,
  });
  final String label;
  final String value;
  final bool obscure;
  final ValueChanged<String> onSaved;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _c = TextEditingController(text: widget.value);
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: TextField(
      controller: _c,
      obscureText: widget.obscure && _hidden,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.obscure)
              IconButton(
                icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.onSaved(_c.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved ${widget.label}')),
                );
              },
            ),
          ],
        ),
      ),
      onSubmitted: (v) => widget.onSaved(v.trim()),
    ),
  );
}

class _TrackerCheck extends StatefulWidget {
  const _TrackerCheck({required this.trackerId});
  final String trackerId;
  @override
  State<_TrackerCheck> createState() => _TrackerCheckState();
}

class _TrackerCheckState extends State<_TrackerCheck> {
  String? _result;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tracker = AppServices.of(context).watchlist.trackers
        .firstWhere((t) => t.id == widget.trackerId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          TextButton(
            onPressed: !tracker.isConnected || _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final name = await tracker.whoAmI();
                      _result = 'Connected as $name';
                    } catch (e) {
                      _result = 'Failed: $e';
                    }
                    if (mounted) setState(() => _busy = false);
                  },
            child: Text('Test ${tracker.name} connection'),
          ),
          if (_result != null)
            Expanded(child: Text(_result!, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
