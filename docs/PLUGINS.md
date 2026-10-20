# Writing a source plug-in

Yume plays from **sources**. The local folder library is one; others can be
added by implementing `MediaSource` (`lib/sources/media_source.dart`).

> Only add sources you are allowed to use: your own files, your own media
> server (Jellyfin / Plex / Emby / a NAS share), or services with a public API
> and the rights to stream. Yume intentionally ships no scrapers for
> unlicensed sites, and plug-ins of that kind won't be merged.

## The interface

```dart
abstract class MediaSource {
  String get id;                // stable, e.g. 'jellyfin'
  String get name;              // shown in the UI
  IconData get icon;
  SourceCapabilities get capabilities;   // search / browse

  Future<void> init();                                   // optional setup
  Future<List<SourceShow>> search(String query);
  Future<List<SourceShow>> browse();                      // optional
  Future<List<SourceEpisode>> episodes(SourceShow show);
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode);
}
```

`PlayableMedia` carries what mpv needs: `uri` (file path or http(s) URL),
optional `httpHeaders` (e.g. an auth token for your server), external
`subtitles`, and `localPath` when the file is local (enables resume keyed by
path and hash-based danmaku matching).

## Minimal example (Jellyfin-style server)

```dart
class MyServerSource extends MediaSource {
  MyServerSource(this.baseUrl, this.token);
  final String baseUrl, token;

  @override String get id => 'myserver';
  @override String get name => 'My media server';
  @override IconData get icon => Icons.dns_outlined;

  @override
  Future<List<SourceShow>> search(String q) async {
    final res = await http.get(Uri.parse('$baseUrl/api/search?q=$q'),
        headers: {'Authorization': 'Bearer $token'});
    return [for (final s in jsonDecode(res.body))
      SourceShow(sourceId: id, id: s['id'], title: s['name'], coverUrl: s['poster'])];
  }

  @override
  Future<List<SourceEpisode>> episodes(SourceShow show) async { /* … */ }

  @override
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode ep) async =>
      PlayableMedia(uri: '$baseUrl/stream/${ep.id}',
                    httpHeaders: {'Authorization': 'Bearer $token'});
}
```

Register it in `AppServices.create()` (`lib/app_services.dart`):

```dart
s.sources
  ..register(LocalLibrarySource(s.library))
  ..register(DirectUrlSource())
  ..register(MyServerSource('https://nas.local:8096', token));
```

It then appears on the **Sources** page with search/browse and plays in the
same player (danmaku, subtitles, speed, resume).

## Ideas for next steps

- Persist per-source config (URL, token) in `AppSettings` and add a config form.
- Let sources return metadata ids (AniList/Bangumi) in `SourceShow.extra` so
  watchlist sync works for streamed shows too.
- Load plug-ins from a folder of declarative JSON manifests for simple REST
  APIs, so new sources don't need a rebuild.
