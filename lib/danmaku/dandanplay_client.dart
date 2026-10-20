import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'danmaku_models.dart';

/// DanDanPlay open API (https://doc.dandanplay.com/open/). Requires an
/// AppId/AppSecret pair; requests are signed with
/// `base64(sha256(appId + timestamp + path + appSecret))`.
class DandanplayClient {
  DandanplayClient({
    required this.appId,
    required this.appSecret,
    required this.cacheDir,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String appId;
  final String appSecret;
  final Future<Directory> Function() cacheDir;
  final http.Client _http;
  static const _host = 'api.dandanplay.net';

  bool get configured => appId.isNotEmpty && appSecret.isNotEmpty;

  Map<String, String> _headers(String path) {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sig = base64.encode(
      sha256.convert(utf8.encode('$appId$ts$path$appSecret')).bytes,
    );
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'yume-anime/0.1',
      'X-AppId': appId,
      'X-Timestamp': ts,
      'X-Signature': sig,
    };
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? q,
  ]) async {
    final res = await _http.get(
      Uri.https(_host, path, q),
      headers: _headers(path),
    );
    if (res.statusCode != 200) {
      throw HttpException('DanDanPlay ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final res = await _http.post(
      Uri.https(_host, path),
      headers: _headers(path),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw HttpException('DanDanPlay ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
        .cast<String, dynamic>();
  }

  /// MD5 of the first 16 MiB, as DanDanPlay's matcher expects.
  static Future<String> fileHash(String path) async {
    final raf = await File(path).open();
    try {
      final bytes = await raf.read(16 * 1024 * 1024);
      return md5.convert(bytes).toString();
    } finally {
      await raf.close();
    }
  }

  /// Matches a local file (hash + name), falling back to a title/episode
  /// search using library metadata. Returns the DanDanPlay episode id.
  Future<DandanMatch?> match(EpisodeFile ep, Show? show) async {
    try {
      final res = await _post('/api/v2/match', {
        'fileName': p.basenameWithoutExtension(ep.fileName),
        'fileHash': await fileHash(ep.path),
        'fileSize': ep.size,
        'matchMode': 'hashAndFileName',
      });
      final matches = (res['matches'] as List? ?? const []).cast<Map>();
      if (matches.isNotEmpty &&
          (res['isMatched'] == true || matches.length == 1)) {
        final m = matches.first;
        return DandanMatch(
          m['episodeId'] as int,
          '${m['animeTitle']} · ${m['episodeTitle']}',
        );
      }
    } catch (_) {
      // fall through to search
    }
    final number = ep.episode;
    final titles = [
      show?.metadata?.titleNative,
      show?.metadata?.title,
      show?.title,
    ].whereType<String>().toSet();
    for (final t in titles) {
      final res = await _get('/api/v2/search/episodes', {
        'anime': t,
        if (number != null) 'episode': ep.episodeKey!,
      });
      final animes = (res['animes'] as List? ?? const []).cast<Map>();
      for (final a in animes) {
        final eps = (a['episodes'] as List? ?? const []).cast<Map>();
        if (eps.isNotEmpty) {
          return DandanMatch(
            eps.first['episodeId'] as int,
            '${a['animeTitle']} · ${eps.first['episodeTitle']}',
          );
        }
      }
    }
    return null;
  }

  /// Comments for an episode, cached on disk for 12 hours.
  Future<List<DanmakuComment>> comments(int episodeId) async {
    final dir = Directory(p.join((await cacheDir()).path, 'danmaku'));
    final cache = File(p.join(dir.path, '$episodeId.json'));
    if (await cache.exists() &&
        DateTime.now().difference(await cache.lastModified()) <
            const Duration(hours: 12)) {
      return parseDandanComments(
        (jsonDecode(await cache.readAsString()) as Map).cast<String, dynamic>(),
      );
    }
    final json = await _get('/api/v2/comment/$episodeId', {
      'withRelated': 'true',
      'chConvert': '0',
    });
    try {
      await dir.create(recursive: true);
      await cache.writeAsString(jsonEncode(json));
    } catch (_) {}
    return parseDandanComments(json);
  }
}

class DandanMatch {
  DandanMatch(this.episodeId, this.label);
  final int episodeId;
  final String label;
}
