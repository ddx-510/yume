import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../media_source.dart';
import 'site_rule.dart';
import 'web_source.dart';

/// Loads user-supplied site rules from `<appSupport>/rules/*.json` and keeps
/// the [SourceRegistry]'s `web:` sources in sync with them. Rules can be added
/// from a file, pasted JSON, or fetched from a URL the user supplies — Yume
/// bundles no rules and defaults to no repository.
class RuleStore extends ChangeNotifier {
  RuleStore(this._dir, this._registry, {http.Client? client})
    : _http = client ?? http.Client();

  final Directory _dir;
  final SourceRegistry _registry;
  final http.Client _http;

  final List<SiteRule> _rules = [];
  List<SiteRule> get rules => List.unmodifiable(_rules);

  /// Source (file name or rule id) -> why it failed to load/validate.
  final Map<String, String> errors = {};

  Future<void> load() async {
    _rules.clear();
    errors.clear();
    if (await _dir.exists()) {
      for (final f in _dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final label = p.basename(f.path);
        try {
          for (final rule in SiteRule.parseList(await f.readAsString())) {
            final problems = rule.validate();
            if (problems.isNotEmpty) {
              errors[rule.rawId] = problems.join('; ');
              continue;
            }
            _rules.removeWhere((r) => r.id == rule.id);
            _rules.add(rule);
          }
        } catch (e) {
          errors[label] = '$e';
          debugPrint('rule $label failed: $e');
        }
      }
    }
    _registry.replaceWithPrefix('web:', _rules.map((r) => WebSource(r)));
    notifyListeners();
  }

  /// Parses, validates and saves one or more rules from JSON text. A rule that
  /// fails validation is rejected with a clear error. Returns the ids saved.
  Future<List<String>> addFromJson(String jsonText) async {
    final parsed = SiteRule.parseList(jsonText); // throws on bad JSON/shape
    final bad = <String>[];
    for (final rule in parsed) {
      final problems = rule.validate();
      if (problems.isNotEmpty) bad.add('${rule.rawId}: ${problems.join('; ')}');
    }
    if (bad.isNotEmpty) throw FormatException(bad.join('\n'));

    await _dir.create(recursive: true);
    final decoded = jsonDecode(jsonText);
    final ids = <String>[];
    for (var i = 0; i < parsed.length; i++) {
      // Persist each rule as its own pretty-printed file.
      final one = decoded is List ? decoded[i] : decoded;
      final file = File(p.join(_dir.path, '${parsed[i].rawId}.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(one));
      ids.add(parsed[i].rawId);
    }
    await load();
    return ids;
  }

  Future<List<String>> importFromFile(String path) async =>
      addFromJson(await File(path).readAsString());

  /// Imports rules from a URL. The URL may return a single rule, a JSON array
  /// of rules, or an index: `{"rules": [{"url": "..."}, ...]}` (each entry's
  /// `url` is fetched) or `{"rules": [ {<inline rule>}, ... ]}`.
  Future<ImportResult> importFromUrl(String url) async {
    final body = await _fetch(url);
    final decoded = jsonDecode(body);

    // Index form: an object with a "rules" array.
    if (decoded is Map && decoded['rules'] is List) {
      final entries = (decoded['rules'] as List).cast();
      final added = <String>[];
      final failed = <String, String>{};
      for (final e in entries) {
        try {
          if (e is Map && e['url'] is String) {
            final childUrl = _resolveUrl(url, e['url'] as String);
            added.addAll(await addFromJson(await _fetch(childUrl)));
          } else if (e is Map) {
            added.addAll(await addFromJson(jsonEncode(e)));
          }
        } catch (err) {
          failed['${(e is Map ? e['name'] ?? e['id'] : e)}'] = '$err';
        }
      }
      return ImportResult(added, failed);
    }

    // Direct form: a single rule or an array of rules.
    try {
      return ImportResult(await addFromJson(body), const {});
    } catch (e) {
      return ImportResult(const [], {url: '$e'});
    }
  }

  Future<String> _fetch(String url) async {
    final res = await _http.get(Uri.parse(url));
    if (res.statusCode >= 400) {
      throw HttpException('HTTP ${res.statusCode} fetching $url');
    }
    return res.body;
  }

  String _resolveUrl(String indexUrl, String child) => child.startsWith('http')
      ? child
      : Uri.parse(indexUrl).resolve(child).toString();

  Future<void> remove(String rawId) async {
    final file = File(p.join(_dir.path, '$rawId.json'));
    if (await file.exists()) await file.delete();
    await load();
  }
}

class ImportResult {
  ImportResult(this.added, this.failed);

  /// Rule ids successfully imported.
  final List<String> added;

  /// Source name/url -> error, for ones that failed.
  final Map<String, String> failed;

  String get summary {
    final parts = <String>[];
    if (added.isNotEmpty) parts.add('added ${added.join(', ')}');
    if (failed.isNotEmpty) parts.add('${failed.length} failed');
    return parts.isEmpty ? 'nothing imported' : parts.join(' · ');
  }
}
