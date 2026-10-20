import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../media_source.dart';
import 'selector_engine.dart';
import 'site_rule.dart';

/// A [MediaSource] driven by a user-supplied [SiteRule]. The engine is
/// generic HTML scraping (CSS or XPath selectors); it ships with no site
/// rules. Only point it at sources you are allowed to use.
class WebSource extends MediaSource {
  WebSource(this.rule, {http.Client? client})
    : _http = client ?? http.Client(),
      _engine = SelectorEngine.forType(rule.selectorType);

  final SiteRule rule;
  final http.Client _http;
  final SelectorEngine _engine;

  @override
  String get id => rule.id;
  @override
  String get name => rule.name;
  @override
  IconData get icon => Icons.public_rounded;
  @override
  SourceCapabilities get capabilities => const SourceCapabilities(search: true);

  Map<String, String> get _headers => {
    'User-Agent':
        rule.userAgent ??
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  Future<String> _get(String url, {Map<String, String>? extra}) async {
    final res = await _http.get(
      Uri.parse(url),
      headers: {..._headers, ...?extra},
    );
    if (res.statusCode >= 400) {
      throw WebSourceException('HTTP ${res.statusCode} for $url');
    }
    return res.body;
  }

  @override
  Future<List<SourceShow>> search(String query) async {
    final url = rule.search.url
        .replaceAll('{query}', Uri.encodeQueryComponent(query))
        .replaceAll('{page}', '1');
    return parseSearch(await _get(url), rule, baseForLinks: url);
  }

  @override
  Future<List<SourceEpisode>> episodes(SourceShow show) async =>
      parseEpisodes(await _get(show.id), rule, baseForLinks: show.id);

  @override
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode) async {
    final stream = await runPipeline(
      rule.video,
      _engine,
      startUrl: episode.id,
      startDoc: await _get(episode.id),
      base: rule.baseUrl,
      fetch: (u) => _get(u, extra: rule.video.headers),
    );
    return PlayableMedia(
      uri: stream,
      httpHeaders: rule.video.headers,
      title: '${show.title} · ${episode.title}',
    );
  }
}

// --- Pure parsing helpers (no network; unit-testable) ----------------------

String _resolve(String base, String url) {
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  try {
    return Uri.parse(base).resolve(url).toString();
  } catch (_) {
    return url;
  }
}

List<SourceShow> parseSearch(
  String body,
  SiteRule rule, {
  required String baseForLinks,
}) {
  final engine = SelectorEngine.forType(rule.selectorType);
  final r = rule.search;
  final out = <SourceShow>[];
  for (final item in engine.items(body, r.item)) {
    final title = engine.field(
      item,
      r.title,
      attr: r.titleAttr,
      fallbackAttr: 'text',
    );
    final link = engine.field(
      item,
      r.link,
      attr: r.linkAttr,
      fallbackAttr: 'href',
    );
    if (title == null || link == null) continue;
    final cover = engine.field(
      item,
      r.cover,
      attr: r.coverAttr,
      fallbackAttr: 'src',
    );
    out.add(
      SourceShow(
        sourceId: rule.id,
        id: _resolve(baseForLinks, link),
        title: title,
        coverUrl: cover == null ? null : _resolve(rule.baseUrl, cover),
      ),
    );
  }
  return out;
}

List<SourceEpisode> parseEpisodes(
  String body,
  SiteRule rule, {
  required String baseForLinks,
}) {
  final engine = SelectorEngine.forType(rule.selectorType);
  final r = rule.episodes;
  final out = <SourceEpisode>[];
  var n = 0;
  for (final item in engine.items(body, r.item)) {
    final link = engine.field(
      item,
      r.link,
      attr: r.linkAttr,
      fallbackAttr: 'href',
    );
    if (link == null) continue;
    final title = engine.field(
      item,
      r.title,
      attr: r.titleAttr,
      fallbackAttr: 'text',
    );
    n++;
    out.add(
      SourceEpisode(
        id: _resolve(baseForLinks, link),
        title: title ?? 'Episode $n',
        number: n.toDouble(),
      ),
    );
  }
  return out;
}

/// Runs the extraction pipeline, returning the final stream URL. [fetch] is
/// injected so tests can run without network.
Future<String> runPipeline(
  VideoRule video,
  SelectorEngine engine, {
  required String startUrl,
  required String startDoc,
  required String base,
  required Future<String> Function(String url) fetch,
}) async {
  var url = startUrl;
  var doc = startDoc;
  for (final step in video.steps) {
    if (step.selector != null) {
      final v = engine.docField(
        doc,
        step.selector!,
        attr: step.attr,
        fallbackAttr: 'src',
      );
      if (v == null) {
        throw WebSourceException('No match for selector "${step.selector}"');
      }
      url = v;
    } else if (step.regex != null) {
      final m = RegExp(step.regex!, dotAll: true).firstMatch(doc);
      final v = m?.group(step.group);
      if (v == null || v.isEmpty) {
        throw WebSourceException('Regex "${step.regex}" matched nothing');
      }
      url = v;
    }
    if (step.resolveRelative) url = _resolve(base, url);
    if (step.fetch) doc = await fetch(url);
  }
  return url;
}

class WebSourceException implements Exception {
  WebSourceException(this.message);
  final String message;
  @override
  String toString() => 'WebSource: $message';
}
