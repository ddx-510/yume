/// Plain data models, serialised to JSON for the on-disk stores.
library;

class ShowMetadata {
  ShowMetadata({
    required this.provider,
    this.anilistId,
    this.malId,
    this.bangumiId,
    required this.title,
    this.titleNative,
    this.titleEnglish,
    this.coverUrl,
    this.bannerUrl,
    this.synopsis,
    this.totalEpisodes,
    this.score,
    this.genres = const [],
    this.year,
    this.episodeTitles = const {},
    this.bangumiEpisodeIds = const {},
  });

  /// Which provider produced the primary fields: `anilist` or `bangumi`.
  final String provider;
  final int? anilistId;
  final int? malId;
  final int? bangumiId;
  final String title;
  final String? titleNative;
  final String? titleEnglish;
  final String? coverUrl;
  final String? bannerUrl;
  final String? synopsis;
  final int? totalEpisodes;
  final double? score;
  final List<String> genres;
  final int? year;

  /// Episode number (as string, e.g. "3" or "7.5") -> episode title.
  final Map<String, String> episodeTitles;

  /// Episode number -> Bangumi episode id (needed for Bangumi progress sync).
  final Map<String, int> bangumiEpisodeIds;

  ShowMetadata copyWith({
    int? bangumiId,
    Map<String, String>? episodeTitles,
    Map<String, int>? bangumiEpisodeIds,
    String? synopsis,
    String? titleNative,
    String? coverUrl,
  }) => ShowMetadata(
    provider: provider,
    anilistId: anilistId,
    malId: malId,
    bangumiId: bangumiId ?? this.bangumiId,
    title: title,
    titleNative: titleNative ?? this.titleNative,
    titleEnglish: titleEnglish,
    coverUrl: coverUrl ?? this.coverUrl,
    bannerUrl: bannerUrl,
    synopsis: synopsis ?? this.synopsis,
    totalEpisodes: totalEpisodes,
    score: score,
    genres: genres,
    year: year,
    episodeTitles: episodeTitles ?? this.episodeTitles,
    bangumiEpisodeIds: bangumiEpisodeIds ?? this.bangumiEpisodeIds,
  );

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'anilistId': anilistId,
    'malId': malId,
    'bangumiId': bangumiId,
    'title': title,
    'titleNative': titleNative,
    'titleEnglish': titleEnglish,
    'coverUrl': coverUrl,
    'bannerUrl': bannerUrl,
    'synopsis': synopsis,
    'totalEpisodes': totalEpisodes,
    'score': score,
    'genres': genres,
    'year': year,
    'episodeTitles': episodeTitles,
    'bangumiEpisodeIds': bangumiEpisodeIds,
  };

  factory ShowMetadata.fromJson(Map<String, dynamic> j) => ShowMetadata(
    provider: j['provider'] as String? ?? 'anilist',
    anilistId: j['anilistId'] as int?,
    malId: j['malId'] as int?,
    bangumiId: j['bangumiId'] as int?,
    title: j['title'] as String? ?? '',
    titleNative: j['titleNative'] as String?,
    titleEnglish: j['titleEnglish'] as String?,
    coverUrl: j['coverUrl'] as String?,
    bannerUrl: j['bannerUrl'] as String?,
    synopsis: j['synopsis'] as String?,
    totalEpisodes: j['totalEpisodes'] as int?,
    score: (j['score'] as num?)?.toDouble(),
    genres: (j['genres'] as List?)?.cast<String>() ?? const [],
    year: j['year'] as int?,
    episodeTitles:
        (j['episodeTitles'] as Map?)?.cast<String, String>() ?? const {},
    bangumiEpisodeIds:
        (j['bangumiEpisodeIds'] as Map?)?.cast<String, int>() ?? const {},
  );
}

class EpisodeFile {
  EpisodeFile({
    required this.path,
    required this.fileName,
    required this.size,
    this.episode,
    this.season,
    this.subtitlePaths = const [],
    this.danmakuPath,
  });

  final String path;
  final String fileName;
  final int size;
  final double? episode;
  final int? season;

  /// External subtitle files sitting next to the video (same base name).
  final List<String> subtitlePaths;

  /// Optional local Bilibili-format danmaku XML next to the video.
  final String? danmakuPath;

  /// Key used in metadata maps: "3", "7.5".
  String? get episodeKey => episode == null
      ? null
      : (episode! % 1 == 0 ? episode!.toInt().toString() : episode!.toString());

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'size': size,
    'episode': episode,
    'season': season,
    'subtitlePaths': subtitlePaths,
    'danmakuPath': danmakuPath,
  };

  factory EpisodeFile.fromJson(Map<String, dynamic> j) => EpisodeFile(
    path: j['path'] as String,
    fileName: j['fileName'] as String,
    size: j['size'] as int? ?? 0,
    episode: (j['episode'] as num?)?.toDouble(),
    season: j['season'] as int?,
    subtitlePaths: (j['subtitlePaths'] as List?)?.cast<String>() ?? const [],
    danmakuPath: j['danmakuPath'] as String?,
  );
}

class Show {
  Show({
    required this.id,
    required this.title,
    required this.episodes,
    this.folderPath,
    this.season,
    this.metadata,
    this.matchLocked = false,
  });

  /// Stable id derived from the normalised title (+ season).
  final String id;

  /// Title guessed from file/folder names.
  final String title;
  final String? folderPath;
  final int? season;
  List<EpisodeFile> episodes;
  ShowMetadata? metadata;

  /// True when the user picked the match by hand; rescans keep it.
  bool matchLocked;

  String get displayTitle => metadata?.title ?? title;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'folderPath': folderPath,
    'season': season,
    'episodes': episodes.map((e) => e.toJson()).toList(),
    'metadata': metadata?.toJson(),
    'matchLocked': matchLocked,
  };

  factory Show.fromJson(Map<String, dynamic> j) => Show(
    id: j['id'] as String,
    title: j['title'] as String,
    folderPath: j['folderPath'] as String?,
    season: j['season'] as int?,
    episodes: (j['episodes'] as List)
        .map((e) => EpisodeFile.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    metadata: j['metadata'] == null
        ? null
        : ShowMetadata.fromJson((j['metadata'] as Map).cast<String, dynamic>()),
    matchLocked: j['matchLocked'] as bool? ?? false,
  );
}

class PlaybackProgress {
  PlaybackProgress({
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  /// Considered watched once 85% through, or inside the last 2 minutes of
  /// an episode-length (10 min+) video, i.e. in the ending credits.
  bool get watched =>
      durationMs > 0 &&
      (positionMs / durationMs >= 0.85 ||
          (durationMs >= 600000 && durationMs - positionMs < 120000));

  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0, 1);

  Map<String, dynamic> toJson() => {
    'positionMs': positionMs,
    'durationMs': durationMs,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PlaybackProgress.fromJson(Map<String, dynamic> j) => PlaybackProgress(
    positionMs: j['positionMs'] as int? ?? 0,
    durationMs: j['durationMs'] as int? ?? 0,
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime(2000),
  );
}

enum WatchStatus {
  watching('Watching'),
  planning('Plan to watch'),
  completed('Completed'),
  paused('On hold'),
  dropped('Dropped');

  const WatchStatus(this.label);
  final String label;
}

class WatchEntry {
  WatchEntry({
    required this.showId,
    required this.title,
    this.status = WatchStatus.watching,
    this.progress = 0,
    this.anilistId,
    this.bangumiId,
    this.coverUrl,
    this.totalEpisodes,
    DateTime? updatedAt,
    this.lastSyncedAt,
    this.lastSyncError,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String showId;
  String title;
  WatchStatus status;

  /// Number of episodes watched.
  int progress;
  int? anilistId;
  int? bangumiId;
  String? coverUrl;
  int? totalEpisodes;
  DateTime updatedAt;
  DateTime? lastSyncedAt;
  String? lastSyncError;

  bool get needsSync =>
      lastSyncedAt == null || lastSyncedAt!.isBefore(updatedAt);

  Map<String, dynamic> toJson() => {
    'showId': showId,
    'title': title,
    'status': status.name,
    'progress': progress,
    'anilistId': anilistId,
    'bangumiId': bangumiId,
    'coverUrl': coverUrl,
    'totalEpisodes': totalEpisodes,
    'updatedAt': updatedAt.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'lastSyncError': lastSyncError,
  };

  factory WatchEntry.fromJson(Map<String, dynamic> j) => WatchEntry(
    showId: j['showId'] as String,
    title: j['title'] as String? ?? '',
    status: WatchStatus.values.asNameMap()[j['status']] ?? WatchStatus.watching,
    progress: j['progress'] as int? ?? 0,
    anilistId: j['anilistId'] as int?,
    bangumiId: j['bangumiId'] as int?,
    coverUrl: j['coverUrl'] as String?,
    totalEpisodes: j['totalEpisodes'] as int?,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    lastSyncedAt: DateTime.tryParse(j['lastSyncedAt'] as String? ?? ''),
    lastSyncError: j['lastSyncError'] as String?,
  );
}
