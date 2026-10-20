import 'package:flutter/foundation.dart';

import 'json_store.dart';

const defaultLibraryPath = '/Volumes/Seagate_ddx/07 Anime';

/// User settings. API secrets/tokens live here too (plain JSON in the app's
/// Application Support folder, never in the repo).
class AppSettings {
  AppSettings({
    this.libraryPaths = const [defaultLibraryPath],
    this.metadataProvider = 'anilist',
    this.fetchBangumiEpisodes = true,
    this.danmakuEnabled = true,
    this.danmakuOpacity = 0.85,
    this.danmakuFontSize = 22,
    this.danmakuArea = 0.6,
    this.danmakuDurationSec = 9,
    this.dandanAppId = '',
    this.dandanAppSecret = '',
    this.anilistClientId = '',
    this.anilistToken = '',
    this.bangumiToken = '',
    this.autoSync = true,
    this.cacheDir = '',
    this.ruleRepoUrl = '',
  });

  final List<String> libraryPaths;

  /// Primary metadata source: `anilist` or `bangumi`.
  final String metadataProvider;

  /// Also fetch per-episode titles + ids from Bangumi.
  final bool fetchBangumiEpisodes;

  final bool danmakuEnabled;
  final double danmakuOpacity;
  final double danmakuFontSize;

  /// Fraction of the video height used for scrolling comments.
  final double danmakuArea;
  final double danmakuDurationSec;

  /// DanDanPlay open-platform credentials (https://doc.dandanplay.com/open/).
  final String dandanAppId;
  final String dandanAppSecret;

  final String anilistClientId;
  final String anilistToken;
  final String bangumiToken;
  final bool autoSync;

  /// Where cover images are cached. Empty = `<first library>/.yume/cache`
  /// when that volume is writable, else Application Support.
  final String cacheDir;

  /// Last-used URL to import web-source rules from (no default).
  final String ruleRepoUrl;

  AppSettings copyWith({
    List<String>? libraryPaths,
    String? metadataProvider,
    bool? fetchBangumiEpisodes,
    bool? danmakuEnabled,
    double? danmakuOpacity,
    double? danmakuFontSize,
    double? danmakuArea,
    double? danmakuDurationSec,
    String? dandanAppId,
    String? dandanAppSecret,
    String? anilistClientId,
    String? anilistToken,
    String? bangumiToken,
    bool? autoSync,
    String? cacheDir,
    String? ruleRepoUrl,
  }) => AppSettings(
    libraryPaths: libraryPaths ?? this.libraryPaths,
    metadataProvider: metadataProvider ?? this.metadataProvider,
    fetchBangumiEpisodes: fetchBangumiEpisodes ?? this.fetchBangumiEpisodes,
    danmakuEnabled: danmakuEnabled ?? this.danmakuEnabled,
    danmakuOpacity: danmakuOpacity ?? this.danmakuOpacity,
    danmakuFontSize: danmakuFontSize ?? this.danmakuFontSize,
    danmakuArea: danmakuArea ?? this.danmakuArea,
    danmakuDurationSec: danmakuDurationSec ?? this.danmakuDurationSec,
    dandanAppId: dandanAppId ?? this.dandanAppId,
    dandanAppSecret: dandanAppSecret ?? this.dandanAppSecret,
    anilistClientId: anilistClientId ?? this.anilistClientId,
    anilistToken: anilistToken ?? this.anilistToken,
    bangumiToken: bangumiToken ?? this.bangumiToken,
    autoSync: autoSync ?? this.autoSync,
    cacheDir: cacheDir ?? this.cacheDir,
  );

  Map<String, dynamic> toJson() => {
    'libraryPaths': libraryPaths,
    'metadataProvider': metadataProvider,
    'fetchBangumiEpisodes': fetchBangumiEpisodes,
    'danmakuEnabled': danmakuEnabled,
    'danmakuOpacity': danmakuOpacity,
    'danmakuFontSize': danmakuFontSize,
    'danmakuArea': danmakuArea,
    'danmakuDurationSec': danmakuDurationSec,
    'dandanAppId': dandanAppId,
    'dandanAppSecret': dandanAppSecret,
    'anilistClientId': anilistClientId,
    'anilistToken': anilistToken,
    'bangumiToken': bangumiToken,
    'autoSync': autoSync,
    'cacheDir': cacheDir,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    double dbl(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return AppSettings(
      libraryPaths:
          (j['libraryPaths'] as List?)?.cast<String>() ?? d.libraryPaths,
      metadataProvider: j['metadataProvider'] as String? ?? d.metadataProvider,
      fetchBangumiEpisodes:
          j['fetchBangumiEpisodes'] as bool? ?? d.fetchBangumiEpisodes,
      danmakuEnabled: j['danmakuEnabled'] as bool? ?? d.danmakuEnabled,
      danmakuOpacity: dbl('danmakuOpacity', d.danmakuOpacity),
      danmakuFontSize: dbl('danmakuFontSize', d.danmakuFontSize),
      danmakuArea: dbl('danmakuArea', d.danmakuArea),
      danmakuDurationSec: dbl('danmakuDurationSec', d.danmakuDurationSec),
      dandanAppId: j['dandanAppId'] as String? ?? '',
      dandanAppSecret: j['dandanAppSecret'] as String? ?? '',
      anilistClientId: j['anilistClientId'] as String? ?? '',
      anilistToken: j['anilistToken'] as String? ?? '',
      bangumiToken: j['bangumiToken'] as String? ?? '',
      autoSync: j['autoSync'] as bool? ?? true,
      cacheDir: j['cacheDir'] as String? ?? '',
      ruleRepoUrl: j['ruleRepoUrl'] as String? ?? '',
    );
  }
}

class SettingsService extends ChangeNotifier {
  SettingsService(this._store);

  final JsonStore _store;
  AppSettings _value = AppSettings();
  AppSettings get value => _value;

  Future<void> load() async {
    final data = await _store.read();
    if (data is Map) {
      _value = AppSettings.fromJson(data.cast<String, dynamic>());
    }
    notifyListeners();
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    _value = change(_value);
    notifyListeners();
    await _store.write(_value.toJson());
  }
}
