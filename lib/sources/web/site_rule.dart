import 'dart:convert';

import 'selector_engine.dart';

/// A declarative description of how to scrape one website, loaded from a JSON
/// file the user supplies. Yume ships the engine, not the rules: point it at a
/// source you are allowed to use. See docs/PLUGINS.md.
///
/// Shape (all selectors are CSS; attrs default to href/src/text):
/// ```json
/// {
///   "id": "example",
///   "name": "Example",
///   "baseUrl": "https://example.test",
///   "userAgent": "optional override",
///   "search": {
///     "url": "https://example.test/search?q={query}&page={page}",
///     "item": ".result",
///     "title": ".title",
///     "link": "a", "linkAttr": "href",
///     "cover": "img", "coverAttr": "src"
///   },
///   "episodes": {
///     "item": ".episode",
///     "title": "a",
///     "link": "a", "linkAttr": "href"
///   },
///   "video": {
///     "steps": [
///       {"selector": "iframe", "attr": "src"},
///       {"resolveRelative": true},
///       {"fetch": true},
///       {"regex": "file:\\s*\"(.*?\\.m3u8[^\"]*)\""}
///     ],
///     "headers": {"Referer": "https://example.test/"}
///   }
/// }
/// ```
class SiteRule {
  SiteRule({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.search,
    required this.episodes,
    required this.video,
    this.selectorType = 'css',
    this.userAgent,
  });

  final String id;
  final String name;
  final String baseUrl;

  /// `css` (default) or `xpath` — the selector language used throughout.
  final String selectorType;
  final String? userAgent;
  final SearchRule search;
  final EpisodesRule episodes;
  final VideoRule video;

  factory SiteRule.fromJson(Map<String, dynamic> j) {
    for (final k in ['id', 'name', 'baseUrl', 'search', 'episodes', 'video']) {
      if (j[k] == null) throw FormatException('Rule is missing "$k"');
    }
    return SiteRule(
      id: 'web:${j['id']}',
      name: j['name'] as String,
      baseUrl: (j['baseUrl'] as String).trimRight(),
      selectorType: (j['selectorType'] as String? ?? 'css').toLowerCase(),
      userAgent: j['userAgent'] as String?,
      search: SearchRule.fromJson((j['search'] as Map).cast()),
      episodes: EpisodesRule.fromJson((j['episodes'] as Map).cast()),
      video: VideoRule.fromJson((j['video'] as Map).cast()),
    );
  }

  /// The raw id without the `web:` prefix (as written in the file).
  String get rawId => id.startsWith('web:') ? id.substring(4) : id;

  /// Human-readable problems with this rule (empty = usable). This is beyond
  /// what [fromJson] enforces: it checks values, not just presence.
  List<String> validate() {
    final engine = SelectorEngine.forType(selectorType);
    final out = <String>[];
    if (rawId.trim().isEmpty) out.add('id is empty');
    if (name.trim().isEmpty) out.add('name is empty');
    if (!baseUrl.startsWith('http')) out.add('baseUrl must be an http(s) URL');
    if (selectorType != 'css' && selectorType != 'xpath') {
      out.add('selectorType must be "css" or "xpath"');
      return out; // can't validate selectors against an unknown engine
    }
    if (!search.url.contains('{query}')) {
      out.add('search.url must contain the {query} placeholder');
    }
    void sel(String? s, String where) {
      if (s == null || s.isEmpty) return;
      final err = engine.validateSelector(s);
      if (err != null) out.add('$where: $err');
    }

    if (search.item.isEmpty) out.add('search.item is empty');
    sel(search.item, 'search.item');
    sel(search.title, 'search.title');
    sel(search.link, 'search.link');
    sel(search.cover, 'search.cover');
    if (episodes.item.isEmpty) out.add('episodes.item is empty');
    sel(episodes.item, 'episodes.item');
    sel(episodes.title, 'episodes.title');
    sel(episodes.link, 'episodes.link');
    if (video.steps.isEmpty) out.add('video.steps is empty');
    for (var i = 0; i < video.steps.length; i++) {
      final step = video.steps[i];
      if (step.selector == null &&
          step.regex == null &&
          !step.fetch &&
          !step.resolveRelative) {
        out.add('video.steps[$i] does nothing');
      }
      sel(step.selector, 'video.steps[$i].selector');
      if (step.regex != null) {
        try {
          RegExp(step.regex!);
        } catch (_) {
          out.add('video.steps[$i]: invalid regex');
        }
      }
    }
    return out;
  }

  static List<SiteRule> parseList(String jsonText) {
    final data = jsonDecode(jsonText);
    final list = data is List ? data : [data];
    return [
      for (final e in list)
        SiteRule.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }
}

class SearchRule {
  SearchRule({
    required this.url,
    required this.item,
    required this.title,
    this.titleAttr,
    this.link,
    this.linkAttr = 'href',
    this.cover,
    this.coverAttr = 'src',
  });

  /// URL template with `{query}` (required) and optional `{page}`.
  final String url;
  final String item;
  final String title;
  final String? titleAttr;
  final String? link;
  final String linkAttr;
  final String? cover;
  final String coverAttr;

  factory SearchRule.fromJson(Map<String, dynamic> j) => SearchRule(
    url: j['url'] as String,
    item: j['item'] as String,
    title: j['title'] as String,
    titleAttr: j['titleAttr'] as String?,
    link: j['link'] as String?,
    linkAttr: j['linkAttr'] as String? ?? 'href',
    cover: j['cover'] as String?,
    coverAttr: j['coverAttr'] as String? ?? 'src',
  );
}

class EpisodesRule {
  EpisodesRule({
    required this.item,
    required this.title,
    this.titleAttr,
    this.link,
    this.linkAttr = 'href',
  });

  final String item;
  final String title;
  final String? titleAttr;
  final String? link;
  final String linkAttr;

  factory EpisodesRule.fromJson(Map<String, dynamic> j) => EpisodesRule(
    item: j['item'] as String,
    title: j['title'] as String,
    titleAttr: j['titleAttr'] as String?,
    link: j['link'] as String?,
    linkAttr: j['linkAttr'] as String? ?? 'href',
  );
}

class VideoRule {
  VideoRule({required this.steps, this.headers = const {}});

  final List<ExtractStep> steps;

  /// Headers sent when the player finally fetches the stream (e.g. Referer).
  final Map<String, String> headers;

  factory VideoRule.fromJson(Map<String, dynamic> j) => VideoRule(
    steps: [
      for (final s in (j['steps'] as List? ?? const []))
        ExtractStep.fromJson((s as Map).cast<String, dynamic>()),
    ],
    headers:
        (j['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
  );
}

/// One transformation in the stream-extraction pipeline. The pipeline carries
/// a "current document" (HTML text) and a "current URL"; each step reads or
/// rewrites them.
class ExtractStep {
  ExtractStep({
    this.selector,
    this.attr,
    this.regex,
    this.group = 1,
    this.fetch = false,
    this.resolveRelative = false,
  });

  /// Take an attribute (or text) of the first element matching this CSS
  /// selector in the current document; the value becomes the current URL.
  final String? selector;
  final String? attr;

  /// Run this regex over the current document; [group] becomes the current URL.
  final String? regex;
  final int group;

  /// GET the current URL; its body becomes the current document.
  final bool fetch;

  /// Resolve the current URL against the site base / previous URL.
  final bool resolveRelative;

  factory ExtractStep.fromJson(Map<String, dynamic> j) => ExtractStep(
    selector: j['selector'] as String?,
    attr: j['attr'] as String?,
    regex: j['regex'] as String?,
    group: j['group'] as int? ?? 1,
    fetch: j['fetch'] as bool? ?? false,
    resolveRelative: j['resolveRelative'] as bool? ?? false,
  );
}
