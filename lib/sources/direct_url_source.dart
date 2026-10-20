import 'package:flutter/material.dart';

import 'media_source.dart';

/// Example plug-in: plays a stream URL the user pastes (e.g. a file served by
/// your own NAS or media server). Doubles as a template for new sources.
class DirectUrlSource extends MediaSource {
  @override
  String get id => 'url';
  @override
  String get name => 'Direct URL';
  @override
  IconData get icon => Icons.link;

  @override
  Future<List<SourceShow>> search(String query) async {
    final uri = Uri.tryParse(query.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return const [];
    }
    final name = uri.pathSegments.isEmpty
        ? uri.host
        : Uri.decodeComponent(uri.pathSegments.last);
    return [SourceShow(sourceId: id, id: uri.toString(), title: name)];
  }

  @override
  Future<List<SourceEpisode>> episodes(SourceShow show) async => [
    SourceEpisode(id: show.id, title: show.title, number: 1),
  ];

  @override
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode) async =>
      PlayableMedia(uri: episode.id, title: episode.title);
}
