import 'package:flutter_test/flutter_test.dart';
import 'package:yume/sources/web/site_rule.dart';
import 'package:yume/sources/web/selector_engine.dart';
import 'package:yume/sources/web/web_source.dart';

const _ruleJson = '''
{
  "id": "demo",
  "name": "Demo",
  "baseUrl": "https://demo.test",
  "search": {
    "url": "https://demo.test/search?q={query}",
    "item": ".card",
    "title": ".name",
    "link": "a", "linkAttr": "href",
    "cover": "img", "coverAttr": "data-src"
  },
  "episodes": {
    "item": "ul.eps li",
    "title": "a",
    "link": "a", "linkAttr": "href"
  },
  "video": {
    "steps": [
      {"selector": "iframe#player", "attr": "src"},
      {"resolveRelative": true},
      {"fetch": true},
      {"regex": "source:\\\\s*\\"(.*?\\\\.m3u8[^\\"]*)\\""}
    ],
    "headers": {"Referer": "https://demo.test/"}
  }
}
''';

void main() {
  final rule = SiteRule.parseList(_ruleJson).single;

  test('rule parses', () {
    expect(rule.id, 'web:demo');
    expect(rule.rawId, 'demo');
    expect(rule.baseUrl, 'https://demo.test');
    expect(rule.video.steps.length, 4);
    expect(rule.video.headers['Referer'], 'https://demo.test/');
  });

  test('missing field throws a clear error', () {
    expect(
      () => SiteRule.parseList('{"id":"x","name":"X"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parseSearch extracts shows and resolves relative links', () {
    const body = '''
      <div class="card"><a href="/anime/1"><span class="name">Alpha</span></a>
        <img data-src="/img/a.jpg"></div>
      <div class="card"><a href="https://demo.test/anime/2"><span class="name">Beta</span></a>
        <img data-src="https://cdn.test/b.jpg"></div>
      <div class="card"><span class="name">No link</span></div>
    ''';
    final shows = parseSearch(body, rule, baseForLinks: 'https://demo.test/s');
    expect(shows.map((s) => s.title), ['Alpha', 'Beta']);
    expect(shows[0].id, 'https://demo.test/anime/1');
    expect(shows[0].coverUrl, 'https://demo.test/img/a.jpg');
    expect(shows[1].coverUrl, 'https://cdn.test/b.jpg');
  });

  test('parseEpisodes numbers and titles episodes', () {
    const body = '''
      <ul class="eps">
        <li><a href="/watch/1-1">EP 1</a></li>
        <li><a href="/watch/1-2">EP 2</a></li>
      </ul>''';
    final eps = parseEpisodes(
      body,
      rule,
      baseForLinks: 'https://demo.test/anime/1',
    );
    expect(eps.length, 2);
    expect(eps[0].title, 'EP 1');
    expect(eps[0].number, 1);
    expect(eps[1].id, 'https://demo.test/watch/1-2');
  });

  test('runPipeline follows iframe then extracts stream', () async {
    const episodePage =
        '<html><iframe id="player" src="/embed/42"></iframe></html>';
    const embedPage =
        'var s = { source: "https://cdn.test/live/42/index.m3u8?t=9" };';
    final fetched = <String>[];
    final stream = await runPipeline(
      rule.video,
      SelectorEngine.forType(rule.selectorType),
      startUrl: 'https://demo.test/watch/1-1',
      startDoc: episodePage,
      base: rule.baseUrl,
      fetch: (u) async {
        fetched.add(u);
        return embedPage;
      },
    );
    expect(stream, 'https://cdn.test/live/42/index.m3u8?t=9');
    expect(fetched, ['https://demo.test/embed/42']);
  });

  test('runPipeline throws when a selector matches nothing', () {
    expect(
      () => runPipeline(
        rule.video,
        SelectorEngine.forType(rule.selectorType),
        startUrl: 'https://demo.test/x',
        startDoc: '<html></html>',
        base: rule.baseUrl,
        fetch: (_) async => '',
      ),
      throwsA(isA<WebSourceException>()),
    );
  });
}
