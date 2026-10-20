import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../services/metadata/anilist_client.dart';
import '../../services/settings_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

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
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const PageHeader(title: 'Settings'),
              _Section(
                title: 'Library',
                children: [
                  for (final path in s.libraryPaths)
                    _Row(
                      icon: Icons.folder_rounded,
                      title: path,
                      trailing: IconButton(
                        tooltip: 'Remove folder',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Palette.textFaint,
                        ),
                        onPressed: () => set(
                          (v) => v.copyWith(
                            libraryPaths: v.libraryPaths
                                .where((x) => x != path)
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add folder'),
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
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Rescan'),
                          onPressed: () => app.library.rescan(),
                        ),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.cloud_download_rounded,
                            size: 18,
                          ),
                          label: const Text('Re-fetch metadata'),
                          onPressed: () =>
                              app.library.rescan(refetchMetadata: true),
                        ),
                      ],
                    ),
                  ),
                  _Row(
                    title: 'Metadata source',
                    trailing: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'anilist', label: Text('AniList')),
                        ButtonSegment(value: 'bangumi', label: Text('Bangumi')),
                      ],
                      selected: {s.metadataProvider},
                      onSelectionChanged: (v) =>
                          set((x) => x.copyWith(metadataProvider: v.first)),
                    ),
                  ),
                  _Row(
                    title: 'Episode titles from Bangumi',
                    trailing: Switch(
                      value: s.fetchBangumiEpisodes,
                      onChanged: (v) =>
                          set((x) => x.copyWith(fetchBangumiEpisodes: v)),
                    ),
                  ),
                  _Field(
                    label: 'Cache folder',
                    hint: 'Default: <first library>/.yume/cache',
                    value: s.cacheDir,
                    onSaved: (v) => set((x) => x.copyWith(cacheDir: v)),
                  ),
                ],
              ),
              _Section(
                title: 'Danmaku',
                children: [
                  _Row(
                    title: 'Show danmaku',
                    trailing: Switch(
                      value: s.danmakuEnabled,
                      onChanged: (v) =>
                          set((x) => x.copyWith(danmakuEnabled: v)),
                    ),
                  ),
                  _Slider(
                    'Opacity',
                    s.danmakuOpacity,
                    0.2,
                    1,
                    (v) => set((x) => x.copyWith(danmakuOpacity: v)),
                    format: (v) => '${(v * 100).round()}%',
                  ),
                  _Slider(
                    'Font size',
                    s.danmakuFontSize,
                    14,
                    40,
                    (v) => set((x) => x.copyWith(danmakuFontSize: v)),
                    format: (v) => '${v.round()}',
                  ),
                  _Slider(
                    'Screen area',
                    s.danmakuArea,
                    0.2,
                    1,
                    (v) => set((x) => x.copyWith(danmakuArea: v)),
                    format: (v) => '${(v * 100).round()}%',
                  ),
                  _Slider(
                    'Scroll time',
                    s.danmakuDurationSec,
                    4,
                    16,
                    (v) => set((x) => x.copyWith(danmakuDurationSec: v)),
                    format: (v) => '${v.round()} s',
                  ),
                  const _Note(
                    'Online danmaku uses DanDanPlay (doc.dandanplay.com/open). '
                    'Without keys, a Bilibili-style <video>.xml next to the file is used.',
                  ),
                  _Field(
                    label: 'DanDanPlay AppId',
                    value: s.dandanAppId,
                    onSaved: (v) => set((x) => x.copyWith(dandanAppId: v)),
                  ),
                  _Field(
                    label: 'DanDanPlay AppSecret',
                    value: s.dandanAppSecret,
                    obscure: true,
                    onSaved: (v) => set((x) => x.copyWith(dandanAppSecret: v)),
                  ),
                ],
              ),
              _Section(
                title: 'Tracking',
                children: [
                  _Row(
                    title: 'Auto-sync progress',
                    trailing: Switch(
                      value: s.autoSync,
                      onChanged: (v) => set((x) => x.copyWith(autoSync: v)),
                    ),
                  ),
                  const _Note(
                    'AniList: create a client at anilist.co/settings/developer with redirect '
                    'https://anilist.co/api/v2/oauth/pin, then Authorize and paste the token.',
                  ),
                  _Field(
                    label: 'AniList Client ID',
                    value: s.anilistClientId,
                    onSaved: (v) => set((x) => x.copyWith(anilistClientId: v)),
                    action: TextButton(
                      onPressed: s.anilistClientId.isEmpty
                          ? null
                          : () => launchUrl(
                              AniListClient.authorizeUrl(s.anilistClientId),
                            ),
                      child: const Text('Authorize'),
                    ),
                  ),
                  _Field(
                    label: 'AniList token',
                    value: s.anilistToken,
                    obscure: true,
                    onSaved: (v) => set((x) => x.copyWith(anilistToken: v)),
                  ),
                  const _TrackerCheck(trackerId: 'anilist'),
                  const _Note(
                    'Bangumi: create a token at next.bgm.tv/demo/access-token.',
                  ),
                  _Field(
                    label: 'Bangumi token',
                    value: s.bangumiToken,
                    obscure: true,
                    onSaved: (v) => set((x) => x.copyWith(bangumiToken: v)),
                  ),
                  const _TrackerCheck(trackerId: 'bangumi'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 8, 36, 0),
                child: Text(
                  'Data: ${app.dataDir.path}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Palette.textFaint,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.trailing, this.icon});
  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Palette.textDim),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(title)),
        ?trailing,
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.5,
        color: Palette.textFaint,
      ),
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider(
    this.label,
    this.value,
    this.min,
    this.max,
    this.onChanged, {
    required this.format,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 260,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            format(value),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Palette.textDim),
          ),
        ),
      ],
    ),
  );
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onSaved,
    this.hint,
    this.obscure = false,
    this.action,
  });
  final String label;
  final String value;
  final String? hint;
  final bool obscure;
  final ValueChanged<String> onSaved;
  final Widget? action;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _c = TextEditingController(text: widget.value);
  bool _hidden = true;

  void _save() {
    widget.onSaved(_c.text.trim());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Saved ${widget.label}')));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(widget.label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: TextField(
            controller: _c,
            obscureText: widget.obscure && _hidden,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Not set',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.obscure)
                    IconButton(
                      iconSize: 16,
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Palette.textFaint,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  IconButton(
                    tooltip: 'Save',
                    iconSize: 16,
                    icon: const Icon(Icons.check_rounded),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        if (widget.action != null) ...[
          const SizedBox(width: 8),
          widget.action!,
        ],
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 0, 20, 6),
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
            child: Text('Test ${tracker.name}'),
          ),
          if (_result != null)
            Expanded(
              child: Text(
                _result!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Palette.textDim),
              ),
            ),
        ],
      ),
    );
  }
}
