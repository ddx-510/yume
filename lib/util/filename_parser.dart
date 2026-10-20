/// Parses anime release file names like
///   `[SubsPlease] Sousou no Frieren - 03 (1080p) [ABCD1234].mkv`
///   `Frieren.S01E03.1080p.WEB-DL.mkv`
///   `葬送的芙莉莲 第03话.mp4`
/// into a show title guess plus season/episode numbers.
library;

class ParsedFileName {
  const ParsedFileName({
    required this.title,
    this.episode,
    this.season,
    this.group,
    this.isSpecial = false,
  });

  /// Best guess at the show title (may be empty if the name has no title).
  final String title;
  final double? episode;
  final int? season;
  final String? group;
  final bool isSpecial;

  @override
  String toString() =>
      'ParsedFileName(title: $title, season: $season, episode: $episode, group: $group, special: $isSpecial)';
}

const videoExtensions = {
  'mkv',
  'mp4',
  'avi',
  'mov',
  'm4v',
  'webm',
  'flv',
  'ts',
  'm2ts',
  'wmv',
  'rmvb',
};

const subtitleExtensions = {'ass', 'ssa', 'srt', 'vtt', 'sub'};

final _bracketed = RegExp(r'\[[^\]]*\]|\([^)]*\)|【[^】]*】|「[^」]*」');
final _leadingGroup = RegExp(r'^\s*[\[【]([^\]】]+)[\]】]');
final _sxxexx = RegExp(
  r'\bS(\d{1,2})\s*E(\d{1,4}(?:\.\d)?)\b',
  caseSensitive: false,
);
final _epWord = RegExp(
  r'(?:\b(?:EP?|Episode|Ep\.)\s*|第\s*)(\d{1,4}(?:\.\d)?)\s*(?:话|話|集)?',
  caseSensitive: false,
);
final _dashNumber = RegExp(r'\s[-–—]\s*(\d{1,4}(?:\.\d)?)(?:v\d)?(?=\s|$)');
final _bracketNumber = RegExp(r'[\[【](\d{1,4}(?:\.\d)?)(?:v\d)?[\]】]');
final _trailingNumber = RegExp(r'(?:^|\s)(\d{1,4}(?:\.\d)?)(?:v\d)?\s*$');
final _seasonWord = RegExp(
  r'\b(?:S(\d{1,2})|Season\s*(\d{1,2})|(\d)(?:nd|rd|th)\s+Season)\b|第(\d{1,2})季',
  caseSensitive: false,
);
final _special = RegExp(
  r'\b(OVA|OAD|SP|Special|NCOP|NCED|PV|Preview|Menu)\b',
  caseSensitive: false,
);
final _noise = RegExp(
  r'\b(1080p|720p|480p|2160p|4k|x264|x265|h\.?264|h\.?265|hevc|avc|aac|flac|'
  r'opus|10bit|8bit|hi10p|web-?dl|webrip|bdrip|bd|bluray|dvdrip|hdtv|'
  r'multi-?subs?|dual[- ]audio|uncensored|batch|end|fin)\b',
  caseSensitive: false,
);

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  final ext = name.substring(dot + 1).toLowerCase();
  if (videoExtensions.contains(ext) || subtitleExtensions.contains(ext)) {
    return name.substring(0, dot);
  }
  return name;
}

double? _num(String? s) => s == null ? null : double.tryParse(s);

/// Scene-style names use dots/underscores as word separators
/// (`Show.Name.S01E02`); treat them as spaces when they dominate.
String _normSeparators(String s) {
  final dots = '.'.allMatches(s).length;
  final spaces = ' '.allMatches(s).length;
  final t = s.replaceAll('_', ' ');
  return dots > 0 && dots >= spaces ? t.replaceAll('.', ' ') : t;
}

/// Cleans a title fragment: dots/underscores to spaces, collapses whitespace,
/// trims trailing separators.
String cleanTitle(String s) {
  var t = s.replaceAll(_bracketed, ' ');
  t = _normSeparators(t);
  t = t.replaceAll(_noise, ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'^[\s\-–—:|]+|[\s\-–—:|]+$'), '').trim();
  return t;
}

ParsedFileName parseFileName(String fileName) {
  var base = _stripExtension(fileName);
  final group = _leadingGroup.firstMatch(base)?.group(1)?.trim();
  if (group != null) base = base.replaceFirst(_leadingGroup, '');

  final isSpecial = _special.hasMatch(base);

  int? season;
  double? episode;
  String titlePart = base;

  // 1. S01E03
  final sxe = _sxxexx.firstMatch(base);
  if (sxe != null) {
    season = int.parse(sxe.group(1)!);
    episode = _num(sxe.group(2));
    titlePart = base.substring(0, sxe.start);
  }

  if (episode == null) {
    // Work on a dot-normalised copy for the remaining patterns.
    final n = _normSeparators(base);
    // 2. " - 03"
    final dash = _dashNumber.firstMatch(n);
    // 3. "EP03", "Episode 3", "第03话"
    final word = _epWord.firstMatch(n);
    // 4. "[03]"
    final br = _bracketNumber.firstMatch(n);
    if (dash != null) {
      episode = _num(dash.group(1));
      titlePart = n.substring(0, dash.start);
    } else if (word != null) {
      episode = _num(word.group(1));
      titlePart = n.substring(0, word.start);
    } else if (br != null) {
      episode = _num(br.group(1));
      titlePart = n.substring(0, br.start);
    } else {
      // 5. trailing number after stripping brackets: "Title 03"
      final stripped = n
          .replaceAll(_bracketed, ' ')
          .replaceAll(_noise, ' ')
          .trim();
      final tr = _trailingNumber.firstMatch(stripped);
      if (tr != null) {
        final value = _num(tr.group(1));
        // Avoid treating a year as an episode number.
        if (value != null && !(value >= 1900 && value <= 2100)) {
          episode = value;
          titlePart = stripped.substring(0, tr.start);
        }
      }
    }
  }

  // Season inside title part (e.g. "Title Season 2 - 03", "Title S2 - 03")
  final sw = _seasonWord.firstMatch(titlePart);
  if (sw != null) {
    season ??= int.tryParse(
      sw.group(1) ?? sw.group(2) ?? sw.group(3) ?? sw.group(4) ?? '',
    );
  }

  final title = cleanTitle(titlePart);
  return ParsedFileName(
    title: title,
    episode: episode,
    season: season,
    group: group,
    isSpecial: isSpecial && episode == null,
  );
}

/// Normalises a title for grouping/matching: lowercase, no punctuation,
/// strips season markers.
String normalizeTitle(String title) {
  var t = title.toLowerCase();
  t = t.replaceAll(_seasonWord, ' ');
  t = t.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Title with season markers removed, for metadata searches.
String searchableTitle(String title) {
  final t = title
      .replaceAll(_seasonWord, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t.isEmpty ? title : t;
}
