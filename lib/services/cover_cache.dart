import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads cover/banner images once and serves them from disk. The cache
/// lives next to the media on the external disk when possible, so the Mac's
/// internal drive stays free.
class CoverCache {
  CoverCache(this._resolveDir);

  final Future<Directory> Function() _resolveDir;
  final _inflight = <String, Future<File?>>{};

  Future<File?> get(String url) => _inflight.putIfAbsent(url, () {
    // Block body on purpose: returning the removed future from the
    // callback would make whenComplete wait on itself forever.
    return _fetch(url).whenComplete(() {
      _inflight.remove(url);
    });
  });

  Future<File?> _fetch(String url) async {
    try {
      final dir = await _resolveDir();
      final ext = p.extension(Uri.parse(url).path);
      final file = File(
        p.join(dir.path, '${md5.convert(utf8.encode(url))}$ext'),
      );
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.file && stat.size > 0) return file;
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      await dir.create(recursive: true);
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('cover cache failed for $url: $e');
      return null;
    }
  }
}
