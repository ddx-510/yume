import 'package:flutter_test/flutter_test.dart';
import 'package:yume/sources/web/selector_engine.dart';
import 'package:yume/sources/web/site_rule.dart';
import 'package:yume/sources/web/web_source.dart';

/// Same fixture scraped two ways (CSS vs XPath) must give identical results.
const _fixtureSearch = '''
<div class="search-result">
  <div class="item"><a class="link" href="/anime/1"><span class="t">Alpha</span></a>
    <img class="poster" data-src="/img/a.jpg"></div>
  <div class="item"><a class="link" href="https://x.test/anime/2"><span class="t">Beta</span></a>
    <img class="poster" data-src="/img/b.jpg"></div>
</div>''';

const _fixtureEpisodes = '''
<ul class="eps">
  <li><a href="/watch/1-1">EP 1</a></li>
  <li><a href="/watch/1-2">EP 2</a></li>
</ul>''';

const _episodePage =
    '<html><body><iframe class="frame" src="/embed/42"></iframe></body></html>';
const _embedPage =
    'sources: [{"file":"https://cdn.test/live/42/index.m3u8?t=9"}]';

SiteRule _cssRule() => SiteRule.parseList('''
{
  "id": "css", "name": "CSS", "baseUrl": "https://x.test", "selectorType": "css",
  "search": { "url": "https://x.test/s?q={query}", "item": ".item",
              "title": ".t", "link": "a.link", "linkAttr": "href",
              "cover": "img.poster", "coverAttr": "data-src" },
  "episodes": { "item": "ul.eps li", "title": "a", "link": "a", "linkAttr": "href" },
  "video": { "steps": [ {"selector": "iframe.frame", "attr": "src"},
    {"resolveRelative": true}, {"fetch": true},
    {"regex": "\\"file\\":\\"(.*?\\\\.m3u8[^\\"]*)\\""} ] }
}''').single;

SiteRule _xpathRule() => SiteRule.parseList('''
{
  "id": "xp", "name": "XP", "baseUrl": "https://x.test", "selectorType": "xpath",
  "search": { "url": "https://x.test/s?q={query}", "item": "//div[@class=\\"item\\"]",
              "title": ".//span[@class=\\"t\\"]", "link": ".//a/@href",
              "cover": ".//img/@data-src" },
  "episodes": { "item": "//ul[@class=\\"eps\\"]/li", "title": ".//a", "link": ".//a/@href" },
  "video": { "steps": [ {"selector": "//iframe[@class=\\"frame\\"]/@src"},
    {"resolveRelative": true}, {"fetch": true},
    {"regex": "\\"file\\":\\"(.*?\\\\.m3u8[^\\"]*)\\""} ] }
}''').single;

Future<String> _run(SiteRule rule) => runPipeline(
  rule.video,
  SelectorEngine.forType(rule.selectorType),
  startUrl: 'https://x.test/watch/1-1',
  startDoc: _episodePage,
  base: rule.baseUrl,
  fetch: (_) async => _embedPage,
);

void main() {
  for (final entry in {'css': _cssRule, 'xpath': _xpathRule}.entries) {
    group(entry.key, () {
      final rule = entry.value();

      test('validates clean', () => expect(rule.validate(), isEmpty));

      test('search', () {
        final shows = parseSearch(
          _fixtureSearch,
          rule,
          baseForLinks: 'https://x.test/s',
        );
        expect(shows.map((s) => s.title), ['Alpha', 'Beta']);
        expect(shows[0].id, 'https://x.test/anime/1');
        expect(shows[1].id, 'https://x.test/anime/2');
        expect(shows[0].coverUrl, 'https://x.test/img/a.jpg');
      });

      test('episodes', () {
        final eps = parseEpisodes(
          _fixtureEpisodes,
          rule,
          baseForLinks: 'https://x.test/anime/1',
        );
        expect(eps.map((e) => e.title), ['EP 1', 'EP 2']);
        expect(eps[1].id, 'https://x.test/watch/1-2');
      });

      test('pipeline extracts stream', () async {
        expect(await _run(rule), 'https://cdn.test/live/42/index.m3u8?t=9');
      });
    });
  }

  test('xpath selectorType is recorded', () {
    expect(_xpathRule().selectorType, 'xpath');
    expect(_cssRule().selectorType, 'css');
  });
}
