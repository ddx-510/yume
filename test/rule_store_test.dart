import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yume/sources/media_source.dart';
import 'package:yume/sources/web/rule_store.dart';
import 'package:yume/sources/web/site_rule.dart';

Map<String, dynamic> _rule(String id) => {
  'id': id,
  'name': id.toUpperCase(),
  'baseUrl': 'https://x.test',
  'search': {
    'url': 'https://x.test/s?q={query}',
    'item': '.item',
    'title': '.t',
    'link': 'a',
  },
  'episodes': {'item': 'li', 'title': 'a', 'link': 'a'},
  'video': {
    'steps': [
      {'selector': 'iframe', 'attr': 'src'},
    ],
  },
};

void main() {
  late Directory tmp;
  late SourceRegistry registry;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('yume_rules');
    registry = SourceRegistry();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('validate() flags concrete problems', () {
    final bad = SiteRule.fromJson({
      ..._rule('b'),
      'baseUrl': 'ftp://nope',
      'selectorType': 'xpath',
      'search': {
        'url': 'no-placeholder',
        'item': '//a[',
        'title': '//t',
        'link': '//a',
      },
    });
    final problems = bad.validate().join('\n');
    expect(problems, contains('baseUrl'));
    expect(problems, contains('{query}'));
    expect(problems, contains('invalid XPath'));
  });

  test('addFromJson rejects an invalid rule', () async {
    final store = RuleStore(tmp, registry);
    expect(
      () => store.addFromJson(jsonEncode({..._rule('x'), 'baseUrl': 'nope'})),
      throwsA(isA<FormatException>()),
    );
    expect(registry.sources, isEmpty);
  });

  test('addFromJson saves a valid rule and registers a source', () async {
    final store = RuleStore(tmp, registry);
    final ids = await store.addFromJson(jsonEncode(_rule('good')));
    expect(ids, ['good']);
    expect(registry.byId('web:good'), isNotNull);
    expect(File('${tmp.path}/good.json').existsSync(), isTrue);
  });

  test('importFromUrl handles a single rule', () async {
    final client = MockClient(
      (req) async => http.Response(jsonEncode(_rule('one')), 200),
    );
    final store = RuleStore(tmp, registry, client: client);
    final result = await store.importFromUrl('https://repo.test/one.json');
    expect(result.added, ['one']);
    expect(registry.byId('web:one'), isNotNull);
  });

  test('importFromUrl follows an index of rule URLs', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/index.json')) {
        return http.Response(
          jsonEncode({
            'rules': [
              {'url': 'a.json'},
              {'url': 'b.json'},
            ],
          }),
          200,
        );
      }
      final id = req.url.path.contains('a.json') ? 'a' : 'b';
      return http.Response(jsonEncode(_rule(id)), 200);
    });
    final store = RuleStore(tmp, registry, client: client);
    final result = await store.importFromUrl('https://repo.test/index.json');
    expect(result.added..sort(), ['a', 'b']);
    expect(registry.sources.map((s) => s.id), containsAll(['web:a', 'web:b']));
  });

  test('importFromUrl reports a bad entry without failing the batch', () async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('index.json')) {
        return http.Response(
          jsonEncode({
            'rules': [
              {'url': 'ok.json'},
              {'url': 'bad.json'},
            ],
          }),
          200,
        );
      }
      if (req.url.path.contains('ok.json')) {
        return http.Response(jsonEncode(_rule('ok')), 200);
      }
      return http.Response(
        jsonEncode({..._rule('bad'), 'baseUrl': 'nope'}),
        200,
      );
    });
    final store = RuleStore(tmp, registry, client: client);
    final result = await store.importFromUrl('https://repo.test/index.json');
    expect(result.added, ['ok']);
    expect(result.failed, isNotEmpty);
  });
}
