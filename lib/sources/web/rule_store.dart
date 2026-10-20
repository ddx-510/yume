import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../media_source.dart';
import 'site_rule.dart';
import 'web_source.dart';

/// Loads user-supplied site rules from `<appSupport>/rules/*.json` and keeps
/// the [SourceRegistry]'s `web:` sources in sync with them.
class RuleStore extends ChangeNotifier {
  RuleStore(this._dir, this._registry);

  final Directory _dir;
  final SourceRegistry _registry;

  final List<SiteRule> _rules = [];
  List<SiteRule> get rules => List.unmodifiable(_rules);

  /// id without the `web:` prefix -> last load error, if any.
  final Map<String, String> errors = {};

  Future<void> load() async {
    _rules.clear();
    errors.clear();
    if (await _dir.exists()) {
      for (final f in _dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        try {
          for (final rule in SiteRule.parseList(await f.readAsString())) {
            _rules.removeWhere((r) => r.id == rule.id);
            _rules.add(rule);
          }
        } catch (e) {
          errors[p.basename(f.path)] = '$e';
          debugPrint('rule ${f.path} failed: $e');
        }
      }
    }
    _registry.replaceWithPrefix('web:', _rules.map(WebSource.new));
    notifyListeners();
  }

  /// Validates and saves one or more rules from pasted/imported JSON, keyed by
  /// rule id so re-importing updates in place. Returns the ids added.
  Future<List<String>> addFromJson(String jsonText) async {
    final parsed = SiteRule.parseList(jsonText); // throws on bad JSON/shape
    await _dir.create(recursive: true);
    final ids = <String>[];
    for (final rule in parsed) {
      final file = File(p.join(_dir.path, '${rule.rawId}.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonText)),
      );
      ids.add(rule.rawId);
    }
    await load();
    return ids;
  }

  Future<void> remove(String rawId) async {
    final file = File(p.join(_dir.path, '$rawId.json'));
    if (await file.exists()) await file.delete();
    await load();
  }

  Future<String> importFromFile(String path) =>
      File(path).readAsString().then(addFromJson).then((ids) => ids.join(', '));
}
