import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/library_service.dart';
import '../util/filename_parser.dart';
import 'media_source.dart';

/// The local folder library exposed through the plug-in interface.
class LocalLibrarySource extends MediaSource {
  LocalLibrarySource(this._library);
  final LibraryService _library;

  @override
  String get id => 'local';
  @override
  String get name => 'Local library';
  @override
  IconData get icon => Icons.folder_special_outlined;
  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(search: true, browse: true);

  SourceShow _toShow(Show show) => SourceShow(
    sourceId: id,
    id: show.id,
    title: show.displayTitle,
    coverUrl: show.metadata?.coverUrl,
    synopsis: show.metadata?.synopsis,
  );

  @override
  Future<List<SourceShow>> browse() async =>
      _library.shows.map(_toShow).toList();

  @override
  Future<List<SourceShow>> search(String query) async {
    final q = normalizeTitle(query);
    return _library.shows
        .where(
          (s) =>
              normalizeTitle(s.displayTitle).contains(q) ||
              normalizeTitle(s.title).contains(q),
        )
        .map(_toShow)
        .toList();
  }

  @override
  Future<List<SourceEpisode>> episodes(SourceShow show) async {
    final s = _library.byId(show.id);
    if (s == null) return const [];
    return [
      for (final e in s.episodes)
        SourceEpisode(
          id: e.path,
          title: s.metadata?.episodeTitles[e.episodeKey] ?? e.fileName,
          number: e.episode,
        ),
    ];
  }

  @override
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode) async {
    final s = _library.byId(show.id);
    final file = s?.episodes.firstWhere((e) => e.path == episode.id);
    return PlayableMedia(
      uri: episode.id,
      localPath: episode.id,
      title: episode.title,
      subtitles: [
        for (final p in file?.subtitlePaths ?? const <String>[])
          SubtitleRef(uri: p),
      ],
    );
  }
}
