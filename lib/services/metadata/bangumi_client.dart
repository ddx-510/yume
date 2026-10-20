import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';

/// Bangumi (bgm.tv) API v0 client (https://bangumi.github.io/api/).
/// Public reads need only a descriptive User-Agent; collection writes need a
/// personal access token from https://next.bgm.tv/demo/access-token.
class BangumiClient {
  BangumiClient({http.Client? client}) : _http = client ?? http.Client();

  static const _base = 'api.bgm.tv';
  static const userAgent = 'yume-anime/0.1 (personal desktop app)';
  final http.Client _http;

  Map<String, String> _headers(String? token) => {
    'User-Agent': userAgent,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    final req = http.Request(method, Uri.https(_base, path, query))
      ..headers.addAll(_headers(token));
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode >= 300) {
      throw BangumiException(
        'HTTP ${res.statusCode}: ${res.body}',
        res.statusCode,
      );
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<ShowMetadata>> search(String keyword, {int limit = 8}) async {
    final data = await _send(
      'POST',
      '/v0/search/subjects',
      query: {'limit': '$limit'},
      body: {
        'keyword': keyword,
        'filter': {
          'type': [2], // anime
        },
      },
    ) as Map;
    return (data['data'] as List)
        .cast<Map>()
        .map((m) => _toMetadata(m.cast()))
        .toList();
  }

  /// Weekly airing schedule (每日放送): weekday (1 = Mon … 7 = Sun) -> shows.
  Future<Map<int, List<ShowMetadata>>> calendar() async {
    final data = await _send('GET', '/calendar') as List;
    final out = <int, List<ShowMetadata>>{};
    for (final day in data.cast<Map>()) {
      final weekday = ((day['weekday'] as Map)['id'] as num).toInt();
      // Most-followed first.
      final items = (day['items'] as List? ?? const []).cast<Map>().toList()
        ..sort(
          (a, b) => ((b['rating'] as Map?)?['total'] as num? ?? 0).compareTo(
            (a['rating'] as Map?)?['total'] as num? ?? 0,
          ),
        );
      out[weekday] = [
        for (final m in items)
          _toMetadata({
            ...m.cast<String, dynamic>(),
            'date': m['air_date'],
            'eps': m['eps_count'] ?? m['eps'],
          }),
      ];
    }
    return out;
  }

  Future<ShowMetadata?> byId(int id) async {
    final m = await _send('GET', '/v0/subjects/$id') as Map?;
    return m == null ? null : _toMetadata(m.cast());
  }

  /// Main-story episodes: returns (episode number -> title, episode number -> id).
  Future<(Map<String, String>, Map<String, int>)> episodes(
    int subjectId,
  ) async {
    final titles = <String, String>{};
    final ids = <String, int>{};
    var offset = 0;
    while (true) {
      final data = await _send(
        'GET',
        '/v0/episodes',
        query: {
          'subject_id': '$subjectId',
          'type': '0',
          'limit': '100',
          'offset': '$offset',
        },
      ) as Map;
      final list = (data['data'] as List).cast<Map>();
      for (final e in list) {
        final num? n = (e['ep'] as num?) ?? (e['sort'] as num?);
        if (n == null) continue;
        final key = n % 1 == 0 ? n.toInt().toString() : n.toString();
        final cn = (e['name_cn'] as String?) ?? '';
        final name = (e['name'] as String?) ?? '';
        if (cn.isNotEmpty || name.isNotEmpty) {
          titles[key] = cn.isNotEmpty ? cn : name;
        }
        ids[key] = e['id'] as int;
      }
      offset += list.length;
      if (list.isEmpty || offset >= (data['total'] as int? ?? 0)) break;
    }
    return (titles, ids);
  }

  // --- Tracking -----------------------------------------------------------

  Future<String> me(String token) async {
    final m = await _send('GET', '/v0/me', token: token) as Map;
    return (m['nickname'] ?? m['username'] ?? '?') as String;
  }

  /// Bangumi collection types: 1 wish, 2 done, 3 doing, 4 on hold, 5 dropped.
  static int collectionType(WatchStatus s) => switch (s) {
    WatchStatus.planning => 1,
    WatchStatus.completed => 2,
    WatchStatus.watching => 3,
    WatchStatus.paused => 4,
    WatchStatus.dropped => 5,
  };

  Future<void> setCollection(
    String token,
    int subjectId,
    WatchStatus status,
  ) async {
    // POST creates or updates the collection entry.
    await _send(
      'POST',
      '/v0/users/-/collections/$subjectId',
      body: {'type': collectionType(status)},
      token: token,
    );
  }

  /// Marks the given episodes as watched (type 2).
  Future<void> markEpisodesWatched(
    String token,
    int subjectId,
    List<int> episodeIds,
  ) async {
    if (episodeIds.isEmpty) return;
    await _send(
      'PATCH',
      '/v0/users/-/collections/$subjectId/episodes',
      body: {'episode_id': episodeIds, 'type': 2},
      token: token,
    );
  }

  ShowMetadata _toMetadata(Map<String, dynamic> m) {
    final images = (m['images'] as Map?)?.cast<String, dynamic>();
    final rating = (m['rating'] as Map?)?.cast<String, dynamic>();
    final date = m['date'] as String?;
    final cn = m['name_cn'] as String?;
    return ShowMetadata(
      provider: 'bangumi',
      bangumiId: m['id'] as int?,
      title: (cn != null && cn.isNotEmpty) ? cn : (m['name'] as String? ?? ''),
      titleNative: m['name'] as String?,
      coverUrl: ((images?['large'] ?? images?['common']) as String?)
          ?.replaceFirst('http://', 'https://'),
      synopsis: (m['summary'] as String?)?.trim(),
      totalEpisodes: (m['eps'] ?? m['total_episodes']) as int?,
      score: (rating?['score'] as num?)?.toDouble(),
      genres: ((m['tags'] as List?) ?? const [])
          .take(6)
          .map((t) => (t as Map)['name'] as String)
          .toList(),
      year: date != null && date.length >= 4
          ? int.tryParse(date.substring(0, 4))
          : null,
    );
  }
}

class BangumiException implements Exception {
  BangumiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => 'Bangumi: $message';
}
