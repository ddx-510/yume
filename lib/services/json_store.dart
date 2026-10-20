import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Tiny JSON-file persistence. Each store is one file in the app support
/// directory; writes go to a temp file first and are renamed into place so a
/// crash mid-write never corrupts the store.
class JsonStore {
  JsonStore(this.directory, this.name);

  final Directory directory;
  final String name;

  File get file => File(p.join(directory.path, '$name.json'));

  Future<dynamic> read() async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void>? _pending;
  dynamic _queued;
  bool _hasQueued = false;

  /// Serialises writes; if several arrive while one is in flight only the
  /// latest is written afterwards.
  Future<void> write(dynamic data) async {
    _queued = data;
    _hasQueued = true;
    if (_pending != null) return _pending;
    _pending = _drain();
    await _pending;
    _pending = null;
  }

  Future<void> _drain() async {
    while (_hasQueued) {
      final data = _queued;
      _hasQueued = false;
      await directory.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
      await tmp.rename(file.path);
    }
  }
}
