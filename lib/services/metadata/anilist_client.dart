import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';

/// AniList GraphQL client (https://docs.anilist.co). Search needs no key;
/// list mutations need a user access token.
class AniListClient {
  AniListClient({http.Client? client}) : _http = client ?? http.Client();

  static final endpoint = Uri.parse('https://graphql.anilist.co');
  final http.Client _http;

  static const _mediaFields = '''
    id idMal episodes averageScore seasonYear genres format
    title { romaji english native userPreferred }
    coverImage { extraLarge large }
    bannerImage
    description(asHtml: false)
  ''';

  Future<Map<String, dynamic>> query(
    String query,
    Map<String, dynamic> variables, {
    String? token,
  }) async {
    final res = await _http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['errors'] != null) {
      final errors = body['errors'] as List?;
      throw AniListException(
        errors?.map((e) => (e as Map)['message']).join('; ') ??
            'HTTP ${res.statusCode}',
        res.statusCode,
      );
    }
    return (body['data'] as Map).cast<String, dynamic>();
  }

  Future<List<ShowMetadata>> search(String title, {int perPage = 8}) async {
    final data = await query(
      '''
      query (\$search: String, \$perPage: Int) {
        Page(perPage: \$perPage) {
          media(search: \$search, type: ANIME, sort: SEARCH_MATCH) { $_mediaFields }
        }
      }''',
      {'search': title, 'perPage': perPage},
    );
    final list = ((data['Page'] as Map)['media'] as List).cast<Map>();
    return list.map((m) => _toMetadata(m.cast<String, dynamic>())).toList();
  }

  Future<ShowMetadata?> byId(int id) async {
    final data = await query(
      '''
      query (\$id: Int) { Media(id: \$id, type: ANIME) { $_mediaFields } }''',
      {'id': id},
    );
    final m = data['Media'] as Map?;
    return m == null ? null : _toMetadata(m.cast<String, dynamic>());
  }

  // --- Tracking -----------------------------------------------------------

  Future<String> viewerName(String token) async {
    final data = await query('query { Viewer { id name } }', {}, token: token);
    return ((data['Viewer'] as Map)['name'] as String?) ?? '?';
  }

  Future<void> saveProgress({
    required String token,
    required int mediaId,
    required int progress,
    required WatchStatus status,
  }) async {
    await query(
      '''
      mutation (\$mediaId: Int, \$progress: Int, \$status: MediaListStatus) {
        SaveMediaListEntry(mediaId: \$mediaId, progress: \$progress, status: \$status) { id progress status }
      }''',
      {
        'mediaId': mediaId,
        'progress': progress,
        'status': switch (status) {
          WatchStatus.watching => 'CURRENT',
          WatchStatus.planning => 'PLANNING',
          WatchStatus.completed => 'COMPLETED',
          WatchStatus.paused => 'PAUSED',
          WatchStatus.dropped => 'DROPPED',
        },
      },
      token: token,
    );
  }

  /// Authorization URL for the implicit grant. With the redirect URL set to
  /// `https://anilist.co/api/v2/oauth/pin` AniList shows the token on a page
  /// for the user to paste back into the app (no local web server needed).
  static Uri authorizeUrl(String clientId) => Uri.https(
    'anilist.co',
    '/api/v2/oauth/authorize',
    {'client_id': clientId, 'response_type': 'token'},
  );

  ShowMetadata _toMetadata(Map<String, dynamic> m) {
    final title = (m['title'] as Map).cast<String, dynamic>();
    final cover = (m['coverImage'] as Map?)?.cast<String, dynamic>();
    final score = m['averageScore'] as num?;
    return ShowMetadata(
      provider: 'anilist',
      anilistId: m['id'] as int?,
      malId: m['idMal'] as int?,
      title:
          (title['userPreferred'] ?? title['romaji'] ?? title['english'] ?? '')
              as String,
      titleEnglish: title['english'] as String?,
      titleNative: title['native'] as String?,
      coverUrl: (cover?['extraLarge'] ?? cover?['large']) as String?,
      bannerUrl: m['bannerImage'] as String?,
      synopsis: _stripHtml(m['description'] as String?),
      totalEpisodes: m['episodes'] as int?,
      score: score == null ? null : score / 10,
      genres: (m['genres'] as List?)?.cast<String>() ?? const [],
      year: m['seasonYear'] as int?,
    );
  }
}

String? _stripHtml(String? s) => s
    ?.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

class AniListException implements Exception {
  AniListException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => 'AniList: $message';
}
