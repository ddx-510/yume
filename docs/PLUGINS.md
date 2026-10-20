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

## Web source rules (the scraper engine)

For sites without an API, Yume has a generic, rule-driven scraper — the same
idea as Kazumi's rule files. You describe a site in JSON; the engine does the
HTTP + HTML parsing. **Yume ships no rules.** Only point it at a source you are
allowed to use (your own server, a public-domain or officially free catalogue).
Do not use it to access pirated content.

Import a rule in **Settings → Web sources** ("Import rule file" or "Paste
JSON"), or drop a `.json` file into `~/Library/Application Support/com.ddx.yume/rules/`
and hit Reload. Each rule becomes a source on the **Sources** page, searchable
and playable in the normal player (resume, subtitles, danmaku by title match).

A rule has three parts — `search`, `episodes`, and a `video` extraction
pipeline. Selectors are CSS; `attr` defaults to `href`/`src`, or use `"text"`
for the element's text. See [example-source-rule.json](example-source-rule.json):

```jsonc
{
  "id": "example",                 // source id (becomes web:example)
  "name": "Example",
  "baseUrl": "https://example.test",
  "userAgent": "…",                // optional
  "search": {
    "url": "https://example.test/search?q={query}&page={page}",
    "item": ".result",             // one element per show
    "title": ".title",
    "link": "a", "linkAttr": "href",
    "cover": "img", "coverAttr": "data-src"
  },
  "episodes": {                    // parsed on the show page
    "item": ".episode",
    "title": "a", "link": "a", "linkAttr": "href"
  },
  "video": {                       // run on the episode page
    "steps": [
      {"selector": "iframe", "attr": "src"},   // grab the player iframe
      {"resolveRelative": true},               // make it absolute
      {"fetch": true},                         // load that page
      {"regex": "file:\"(.*?\\.m3u8[^\"]*)\""} // pull the stream URL
    ],
    "headers": {"Referer": "https://example.test/"}  // sent when playing
  }
}
```

The `video.steps` pipeline carries a *current document* (HTML) and *current
URL*. `selector`/`attr` and `regex` set the URL from the current document;
`fetch` loads the current URL as the new document; `resolveRelative` makes the
URL absolute. The URL after the last step is handed to mpv (HLS/`.m3u8` and
`.mp4` both play), with `headers`. The parsing and pipeline are covered by
`test/web_source_test.dart` and `test/web_xpath_test.dart`.

### CSS or XPath selectors

Set `"selectorType": "xpath"` at the top of a rule to write every selector in
XPath instead of CSS (default is `"css"`). The field meaning is identical; only
the selector language changes. With XPath you usually select the attribute in
the selector itself (`.//a/@href`) rather than via `linkAttr`. Item selectors
return a node set; field selectors run relative to each item (`.` is the item,
`.//` descends). `test/web_xpath_test.dart` scrapes the same fixture with CSS
and XPath and asserts identical output.

### Importing rules

Three ways, in **Settings → Web sources**:

- **Import rule file** — pick a local `.json`.
- **Paste JSON** — paste one rule or an array.
- **Import from URL** — fetch from a URL you enter (remembered between runs,
  **no default**). The URL may return a single rule, an array of rules, or an
  index `{"rules": [{"name": "...", "url": "..."}]}` whose entries are fetched
  and imported. Relative `url`s resolve against the index URL.

Every rule is validated on import and on load (`SiteRule.validate()`); a rule
with a bad selector, a missing `{query}`, an empty step, etc. is rejected with a
specific message instead of silently failing. Imported rules live in
`~/Library/Application Support/com.ddx.yume/rules/`.

Prefer a real `MediaSource` (above) when the site has a clean API — it's more
robust than scraping HTML.

## Ideas for next steps

- Persist per-source config (URL, token) in `AppSettings` and add a config form.
- Let sources return metadata ids (AniList/Bangumi) in `SourceShow.extra` so
  watchlist sync works for streamed shows too.
- Load plug-ins from a folder of declarative JSON manifests for simple REST
  APIs, so new sources don't need a rebuild.
