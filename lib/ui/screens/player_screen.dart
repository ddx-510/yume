import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app_services.dart';
import '../../danmaku/danmaku_models.dart';
import '../../danmaku/danmaku_overlay.dart';
import '../../models/models.dart';
import '../../sources/media_source.dart';
import 'show_detail_screen.dart' show formatDuration;

/// Full-window player: media_kit (libmpv) + resume + danmaku + subtitles.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen.local({
    super.key,
    required Show this.show,
    required EpisodeFile episode,
  }) : initialEpisode = episode,
       media = null;

  const PlayerScreen.media({super.key, required PlayableMedia this.media})
    : show = null,
      initialEpisode = null;

  final Show? show;
  final EpisodeFile? initialEpisode;
  final PlayableMedia? media;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AppServices app = AppServices.of(context);
  late final ScaffoldMessengerState _messenger = ScaffoldMessenger.of(context);
  final player = Player(
    configuration: const PlayerConfiguration(title: 'Yume', libass: true),
  );
  late final controller = VideoController(player);
  final danmaku = DanmakuController();
  final _subs = <StreamSubscription>[];
  Timer? _saveTimer;

  EpisodeFile? _episode;
  String _title = '';
  String? _danmakuStatus;
  bool _markedWatched = false;
  bool _initialised = false;

  /// Bumped on every episode switch so stale async work can bail out.
  int _loadToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _messenger; // resolve while the context is active
    final s = app.settings.value;
    danmaku
      ..enabled = s.danmakuEnabled
      ..style = DanmakuStyle(
        fontSize: s.danmakuFontSize,
        opacity: s.danmakuOpacity,
        area: s.danmakuArea,
        duration: s.danmakuDurationSec,
      );
    _subs.addAll([
      player.stream.position.listen(
        (pos) => danmaku.updateClock(
          pos,
          playing: player.state.playing,
          rate: player.state.rate,
        ),
      ),
      player.stream.playing.listen(
        (playing) => danmaku.updateClock(
          player.state.position,
          playing: playing,
          rate: player.state.rate,
        ),
      ),
      player.stream.rate.listen(
        (rate) => danmaku.updateClock(
          player.state.position,
          playing: player.state.playing,
          rate: rate,
        ),
      ),
      player.stream.completed.listen((done) {
        if (done) _onCompleted();
      }),
      player.stream.error.listen((e) => debugPrint('mpv error: $e')),
    ]);
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveProgress(),
    );
    _configureMpv().then((_) {
      if (widget.initialEpisode != null) {
        _openEpisode(widget.initialEpisode!);
      } else {
        _openMedia(widget.media!, null);
      }
    });
  }

  Future<void> _configureMpv() async {
    final p = player.platform;
    if (p is NativePlayer) {
      // Auto-load external subtitle files next to the video; prefer Chinese,
      // then Japanese, then English subtitle tracks.
      await p.setProperty('sub-auto', 'fuzzy');
      await p.setProperty(
        'slang',
        'chi,zho,zh,chs,sc,zh-Hans,zh-CN,jpn,ja,eng,en',
      );
      await p.setProperty('alang', 'jpn,ja,chi,zh,eng,en');
    }
  }

  Future<void> _openEpisode(EpisodeFile ep) async {
    final show = widget.show!;
    final title = show.metadata?.episodeTitles[ep.episodeKey];
    await _openMedia(
      PlayableMedia(
        uri: ep.path,
        localPath: ep.path,
        title:
            '${show.displayTitle} · ${ep.episodeKey != null ? 'EP ${ep.episodeKey}' : ep.fileName}'
            '${title != null ? ' · $title' : ''}',
        subtitles: [for (final s in ep.subtitlePaths) SubtitleRef(uri: s)],
      ),
      ep,
    );
  }

  Future<void> _openMedia(PlayableMedia media, EpisodeFile? ep) async {
    await _saveProgress();
    final token = ++_loadToken;
    setState(() {
      _episode = ep;
      _title = media.title ?? media.uri;
      _markedWatched = false;
      _danmakuStatus = null;
    });
    danmaku.setComments(const []);

    final key = media.localPath ?? media.uri;
    final resume = app.progress.resumePoint(key);
    await player.open(
      Media(media.uri, httpHeaders: media.httpHeaders),
      play: false,
    );
    if (token != _loadToken) return;

    if (resume != null) {
      // Seeking before the demuxer knows the duration is ignored by mpv.
      try {
        await player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      await player.seek(resume);
    }
    await player.play();
    if (resume != null && mounted) {
      _messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Resumed at ${formatDuration(resume)}'),
            action: SnackBarAction(
              label: 'Start over',
              onPressed: () => player.seek(Duration.zero),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
    }
    _loadDanmaku(media, ep, token);
  }

  Future<void> _loadDanmaku(
    PlayableMedia media,
    EpisodeFile? ep,
    int token,
  ) async {
    void status(String s) {
      if (mounted && token == _loadToken) setState(() => _danmakuStatus = s);
    }

    try {
      // 1. A local Bilibili-format XML next to the video wins.
      final xmlPath = ep?.danmakuPath;
      if (xmlPath != null && await File(xmlPath).exists()) {
        final list = parseBilibiliXml(await File(xmlPath).readAsString());
        if (token != _loadToken) return;
        danmaku.setComments(list, label: 'local XML');
        status('${list.length} comments · local XML');
        return;
      }
      // 2. DanDanPlay, matched by file hash, then by title + episode.
      final client = app.dandanplay();
      if (!client.configured) {
        status('Danmaku: add DanDanPlay AppId/Secret in Settings');
        return;
      }
      if (ep == null) {
        status('Danmaku: only for local files');
        return;
      }
      status('Matching danmaku…');
      final match = await client.match(ep, widget.show);
      if (match == null) {
        status('No danmaku match');
        return;
      }
      final list = await client.comments(match.episodeId);
      if (token != _loadToken) return;
      danmaku.setComments(list, label: match.label);
      status('${list.length} comments · ${match.label}');
    } catch (e) {
      status('Danmaku failed: $e');
    }
  }

  Future<void> _saveProgress() async {
    final key = _episode?.path ?? widget.media?.localPath ?? widget.media?.uri;
    if (key == null) return;
    final pos = player.state.position, dur = player.state.duration;
    if (dur <= Duration.zero || pos <= Duration.zero) return;
    await app.progress.save(key, pos, dur);
    final p = app.progress.of(key);
    if (!_markedWatched &&
        p != null &&
        p.watched &&
        widget.show != null &&
        _episode != null) {
      _markedWatched = true;
      await app.watchlist.onEpisodeWatched(widget.show!, _episode!);
    }
  }

  int get _index =>
      _episode == null ? -1 : widget.show!.episodes.indexOf(_episode!);

  EpisodeFile? _relative(int delta) {
    final show = widget.show;
    if (show == null || _index < 0) return null;
    final i = _index + delta;
    return i >= 0 && i < show.episodes.length ? show.episodes[i] : null;
  }

  void _onCompleted() async {
    await _saveProgress();
    final next = _relative(1);
    if (next != null && mounted) _openEpisode(next);
  }

  @override
  void dispose() {
    _messenger.hideCurrentSnackBar();
    _saveTimer?.cancel();
    // Fire-and-forget final save, then release the player.
    _saveProgress().whenComplete(player.dispose);
    for (final s in _subs) {
      s.cancel();
    }
    danmaku.dispose();
    super.dispose();
  }

  // --- UI -----------------------------------------------------------------

  List<Widget> _topBar(BuildContext context) => [
    MaterialDesktopCustomButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () async {
        if (isFullscreen(context)) await exitFullscreen(context);
        if (mounted) Navigator.of(this.context).maybePop();
      },
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    ),
    if (_danmakuStatus != null)
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          _danmakuStatus!,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
  ];

  List<Widget> _bottomBar() => [
    if (_relative(-1) != null)
      MaterialDesktopCustomButton(
        icon: const Icon(Icons.skip_previous),
        onPressed: () => _openEpisode(_relative(-1)!),
      ),
    const MaterialDesktopPlayOrPauseButton(),
    if (_relative(1) != null)
      MaterialDesktopCustomButton(
        icon: const Icon(Icons.skip_next),
        onPressed: () => _openEpisode(_relative(1)!),
      ),
    const MaterialDesktopVolumeButton(),
    const MaterialDesktopPositionIndicator(),
    const Spacer(),
    ListenableBuilder(
      listenable: danmaku,
      builder: (context, _) => MaterialDesktopCustomButton(
        icon: Icon(
          danmaku.enabled ? Icons.comment : Icons.comments_disabled_outlined,
        ),
        onPressed: () {
          danmaku.enabled = !danmaku.enabled;
          app.settings.update(
            (s) => s.copyWith(danmakuEnabled: danmaku.enabled),
          );
        },
      ),
    ),
    _TrackMenu(player: player, kind: _TrackKind.subtitle),
    _TrackMenu(player: player, kind: _TrackKind.audio),
    _SpeedMenu(player: player),
    const MaterialDesktopFullscreenButton(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = MaterialDesktopVideoControlsThemeData(
      topButtonBar: _topBar(context),
      bottomButtonBar: _bottomBar(),
      seekBarThumbColor: Theme.of(context).colorScheme.primary,
      seekBarPositionColor: Theme.of(context).colorScheme.primary,
      controlsHoverDuration: const Duration(seconds: 2),
      keyboardShortcuts: _shortcuts(),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialDesktopVideoControlsTheme(
        normal: theme,
        fullscreen: theme,
        child: Video(
          controller: controller,
          // Danmaku sits between the picture and the controls, so it also
          // shows in fullscreen (the builder is reused there).
          controls: (state) => Stack(
            fit: StackFit.expand,
            children: [
              DanmakuOverlay(controller: danmaku),
              MaterialDesktopVideoControls(state),
            ],
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    Future<void> seekBy(int s) async {
      final d = player.state.position + Duration(seconds: s);
      await player.seek(d < Duration.zero ? Duration.zero : d);
    }

    return {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          player.playOrPause(),
      const SingleActivator(LogicalKeyboardKey.keyK): () =>
          player.playOrPause(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => seekBy(-5),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => seekBy(5),
      const SingleActivator(LogicalKeyboardKey.keyJ): () => seekBy(-10),
      const SingleActivator(LogicalKeyboardKey.keyL): () => seekBy(10),
      // Skip an opening (~85 s).
      const SingleActivator(LogicalKeyboardKey.keyS): () => seekBy(85),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          player.setVolume((player.state.volume + 5).clamp(0, 100)),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          player.setVolume((player.state.volume - 5).clamp(0, 100)),
      const SingleActivator(LogicalKeyboardKey.keyD): () =>
          danmaku.enabled = !danmaku.enabled,
      const SingleActivator(LogicalKeyboardKey.keyF): () =>
          toggleFullscreen(context),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (isFullscreen(context)) exitFullscreen(context);
      },
      const SingleActivator(LogicalKeyboardKey.keyN): () {
        final n = _relative(1);
        if (n != null) _openEpisode(n);
      },
    };
  }
}

enum _TrackKind { subtitle, audio }

class _TrackMenu extends StatelessWidget {
  const _TrackMenu({required this.player, required this.kind});
  final Player player;
  final _TrackKind kind;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (context, snap) {
        final tracks = snap.data ?? const Tracks();
        final isSub = kind == _TrackKind.subtitle;
        final list = isSub
            ? tracks.subtitle.where((t) => t.id != 'auto').toList()
            : tracks.audio
                  .where((t) => t.id != 'auto' && t.id != 'no')
                  .toList();
        final current = isSub
            ? player.state.track.subtitle
            : player.state.track.audio;
        String label(dynamic t) {
          if (t.id == 'no') return 'Off';
          final parts = [
            t.title,
            t.language,
            t.codec,
          ].whereType<String>().where((s) => s.isNotEmpty);
          return parts.isEmpty ? 'Track ${t.id}' : parts.join(' · ');
        }

        return PopupMenuButton<Object>(
          tooltip: isSub ? 'Subtitles' : 'Audio',
          icon: Icon(
            isSub ? Icons.subtitles : Icons.audiotrack,
            color: Colors.white,
          ),
          itemBuilder: (_) => [
            for (final t in list)
              CheckedPopupMenuItem<Object>(
                value: t,
                checked: t == current,
                child: Text(label(t)),
              ),
          ],
          onSelected: (t) {
            if (t is SubtitleTrack) player.setSubtitleTrack(t);
            if (t is AudioTrack) player.setAudioTrack(t);
          },
        );
      },
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Speed',
      icon: const Icon(Icons.speed, color: Colors.white),
      itemBuilder: (_) => [
        for (final r in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          CheckedPopupMenuItem(
            value: r,
            checked: player.state.rate == r,
            child: Text('${r}x'),
          ),
      ],
      onSelected: player.setRate,
    );
  }
}
