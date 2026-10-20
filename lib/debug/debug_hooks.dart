import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_services.dart';
import '../ui/screens/anime_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/player_screen.dart';
import '../ui/screens/show_detail_screen.dart';

/// Debug-build-only VM service extensions for automated checks:
///   ext.yume.snapshot {path}          — PNG of the widget tree
///   ext.yume.openShow {index}         — push a show's detail page
///   ext.yume.play {index, episode}    — open the player
///   ext.yume.openAnilist {id}        — open a catalogue page
///   ext.yume.tab {index}              — switch home tab
///   ext.yume.sourceResolve {id,q}     — search+episodes+resolve a source
///   ext.yume.sources                  — list registered source ids
///   ext.yume.back                     — pop the top route
///   ext.yume.state                    — JSON summary of library/progress
class DebugHooks {
  static final boundaryKey = GlobalKey();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void register(AppServices app) {
    if (!kDebugMode) return;

    Future<developer.ServiceExtensionResponse> ok(Object data) async =>
        developer.ServiceExtensionResponse.result(jsonEncode(data));

    developer.registerExtension('ext.yume.snapshot', (_, params) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = params['path'] ?? '/tmp/yume_snapshot.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      return ok({'path': path, 'w': image.width, 'h': image.height});
    });

    developer.registerExtension('ext.yume.openShow', (_, params) async {
      final show = app.library.shows[int.parse(params['index'] ?? '0')];
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => ShowDetailScreen(showId: show.id)),
      );
      return ok({'show': show.displayTitle});
    });

    developer.registerExtension('ext.yume.play', (_, params) async {
      final show = app.library.shows[int.parse(params['index'] ?? '0')];
      final ep = show.episodes[int.parse(params['episode'] ?? '0')];
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen.local(show: show, episode: ep),
        ),
      );
      return ok({'show': show.displayTitle, 'episode': ep.fileName});
    });

    developer.registerExtension('ext.yume.openAnilist', (_, params) async {
      final m = await app.metadata.anilist.byId(int.parse(params['id']!));
      openAnime(navigatorKey.currentContext!, m!);
      return ok({'title': m.title});
    });

    developer.registerExtension('ext.yume.tab', (_, params) async {
      HomeScreen.tab.value = int.parse(params['index'] ?? '0');
      return ok({});
    });

    // End-to-end check of a web source: search -> episodes -> resolve.
    developer.registerExtension('ext.yume.sourceResolve', (_, params) async {
      final src = app.sources.byId(params['id']!)!;
      final shows = await src.search(params['q'] ?? '');
      final eps = shows.isEmpty ? [] : await src.episodes(shows.first);
      final media = eps.isEmpty
          ? null
          : await src.resolve(shows.first, eps.first);
      return ok({
        'shows': [for (final s in shows) s.title],
        'episodes': [for (final e in eps) e.title],
        'stream': media?.uri,
        'headers': media?.httpHeaders,
      });
    });

    developer.registerExtension(
      'ext.yume.sources',
      (_, _) async => ok({
        'ids': [for (final s in app.sources.sources) s.id],
      }),
    );

    developer.registerExtension('ext.yume.back', (_, _) async {
      navigatorKey.currentState!.maybePop();
      return ok({});
    });

    developer.registerExtension(
      'ext.yume.state',
      (_, _) async => ok({
        'shows': [
          for (final s in app.library.shows)
            {
              'title': s.displayTitle,
              'episodes': s.episodes.length,
              'anilist': s.metadata?.anilistId,
              'bangumi': s.metadata?.bangumiId,
            },
        ],
        'progress': {
          for (final s in app.library.shows)
            for (final e in s.episodes)
              if (app.progress.of(e.path) != null)
                e.fileName: app.progress.of(e.path)!.toJson(),
        },
        'watchlist': [for (final e in app.watchlist.entries) e.toJson()],
      }),
    );
  }
}
