import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../media_source.dart';
import 'site_rule.dart';

/// A [MediaSource] driven by a user-supplied [SiteRule]. The engine is
/// generic HTML scraping; it ships with no site rules. Only point it at
/// sources you are allowed to use.
class WebSource extends MediaSource {
  WebSource(this.rule, {http.Client? client}) : _http = client ?? http.Client();

  final SiteRule rule;
  final http.Client _http;

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
    final body = await _get(url);
    return parseSearch(body, rule, baseForLinks: url);
  }

  @override
  Future<List<SourceEpisode>> episodes(SourceShow show) async {
    final body = await _get(show.id);
    return parseEpisodes(body, rule, baseForLinks: show.id);
  }

  @override
  Future<PlayableMedia> resolve(SourceShow show, SourceEpisode episode) async {
    final stream = await runPipeline(
      rule.video,
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

String? _value(
  dom.Element el,
  String? selector,
  String? attr,
  String fallback,
) {
  final target = selector == null || selector.isEmpty
      ? el
      : el.querySelector(selector);
  if (target == null) return null;
  final a = attr ?? fallback;
  final String? v;
  if (a == 'text') {
    v = target.text.trim();
  } else {
    v = target.attributes[a] ?? target.attributes['data-$a'];
  }
  return (v == null || v.trim().isEmpty) ? null : v.trim();
}

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
  final doc = html.parse(body);
  final out = <SourceShow>[];
  for (final el in doc.querySelectorAll(rule.search.item)) {
    final title = _value(el, rule.search.title, rule.search.titleAttr, 'text');
    final link = _value(el, rule.search.link, rule.search.linkAttr, 'href');
    if (title == null || link == null) continue;
    final cover = _value(el, rule.search.cover, null, rule.search.coverAttr);
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
  final doc = html.parse(body);
  final out = <SourceEpisode>[];
  var n = 0;
  for (final el in doc.querySelectorAll(rule.episodes.item)) {
    final title = _value(
      el,
      rule.episodes.title,
      rule.episodes.titleAttr,
      'text',
    );
    final link = _value(el, rule.episodes.link, rule.episodes.linkAttr, 'href');
    if (link == null) continue;
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
  VideoRule video, {
  required String startUrl,
  required String startDoc,
  required String base,
  required Future<String> Function(String url) fetch,
}) async {
  var url = startUrl;
  var doc = startDoc;
  for (final step in video.steps) {
    if (step.selector != null) {
      final el = html.parse(doc).querySelector(step.selector!);
      final v = el == null
          ? null
          : (step.attr == 'text'
                ? el.text.trim()
                : el.attributes[step.attr ?? 'src']);
      if (v == null || v.isEmpty) {
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
