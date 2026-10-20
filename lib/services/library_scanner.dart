import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../util/filename_parser.dart';

/// Walks library folders and groups video files into shows.
///
/// Grouping rule: the title parsed from the file name wins; when a file name
/// has no usable title (e.g. `Episode 03.mkv`) the nearest folder name is
/// used. Files whose parsed title matches the folder title share that show.
class LibraryScanner {
  static const _skipDirs = {
    '.yume',
    '\$RECYCLE.BIN',
    'System Volume Information',
  };

  /// Scans [roots] and returns shows keyed by id. Missing roots are skipped
  /// (e.g. the external disk is unplugged) and reported in [missingRoots].
  Future<ScanResult> scan(List<String> roots) async {
    final files = <File>[];
    final missing = <String>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        missing.add(root);
        continue;
      }
      await _collect(dir, files);
    }
    return ScanResult(
      groupFiles(
        files.map((f) => f.path).toList(),
        roots,
        sizeOf: (path) {
          try {
            return File(path).lengthSync();
          } catch (_) {
            return 0;
          }
        },
      ),
      missing,
    );
  }

  Future<void> _collect(Directory dir, List<File> out) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.') || name.startsWith('._')) continue;
        if (entity is Directory) {
          if (_skipDirs.contains(name)) continue;
          await _collect(entity, out);
        } else if (entity is File) {
          final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
          if (videoExtensions.contains(ext)) out.add(entity);
        }
      }
    } on FileSystemException {
      // Unreadable folder: skip it rather than failing the whole scan.
    }
  }
}

class ScanResult {
  ScanResult(this.shows, this.missingRoots);
  final List<Show> shows;
  final List<String> missingRoots;
}

/// Pure grouping logic (separate from IO so it is unit-testable).
List<Show> groupFiles(
  List<String> paths,
  List<String> roots, {
  int Function(String path)? sizeOf,
  bool Function(String path)? exists,
}) {
  final fileExists = exists ?? (String path) => File(path).existsSync();
  final normalizedRoots = roots.map(p.normalize).toSet();
  final groups = <String, _Group>{};

  for (final path in paths) {
    final fileName = p.basename(path);
    final parsed = parseFileName(fileName);
    final folder = p.dirname(path);
    final isRootFolder = normalizedRoots.contains(p.normalize(folder));
    final folderParsed = isRootFolder
        ? null
        : parseFileName(p.basename(folder));
    final folderTitle = folderParsed?.title ?? '';

    var title = parsed.title;
    final weak =
        title.isEmpty ||
        RegExp(r'^(episode|ep|e|第)?\s*$', caseSensitive: false).hasMatch(title);
    if (weak && folderTitle.isNotEmpty) title = folderTitle;
    if (title.isEmpty) title = p.basenameWithoutExtension(fileName);

    final season = parsed.season ?? folderParsed?.season;
    var key = normalizeTitle(title);
    // Prefer the folder grouping when the file title is just a variant of it.
    if (folderTitle.isNotEmpty) {
      final fk = normalizeTitle(folderTitle);
      if (fk.isNotEmpty && (key.startsWith(fk) || fk.startsWith(key))) {
        key = fk;
        title = folderTitle;
      }
    }
    final id = season != null && season > 1 ? '$key#s$season' : key;

    final group = groups.putIfAbsent(
      id,
      () => _Group(
        id: id,
        title: title,
        season: season,
        folder: isRootFolder ? null : folder,
      ),
    );

    final base = p.withoutExtension(path);
    final subs = <String>[];
    for (final ext in subtitleExtensions) {
      for (final candidate in [
        '$base.$ext',
        '$base.zh.$ext',
        '$base.chs.$ext',
        '$base.en.$ext',
      ]) {
        if (fileExists(candidate)) subs.add(candidate);
      }
    }
    final danmaku = fileExists('$base.xml') ? '$base.xml' : null;

    group.episodes.add(
      EpisodeFile(
        path: path,
        fileName: fileName,
        size: sizeOf?.call(path) ?? 0,
        episode: parsed.episode,
        season: season,
        subtitlePaths: subs,
        danmakuPath: danmaku,
      ),
    );
  }

  final shows =
      groups.values.map((g) {
        g.episodes.sort((a, b) {
          final ea = a.episode ?? 1e9, eb = b.episode ?? 1e9;
          final c = ea.compareTo(eb);
          return c != 0 ? c : a.fileName.compareTo(b.fileName);
        });
        // A single un-numbered file in a show is episode 1 (movies, OVAs).
        if (g.episodes.length == 1 && g.episodes.first.episode == null) {
          final e = g.episodes.first;
          g.episodes[0] = EpisodeFile(
            path: e.path,
            fileName: e.fileName,
            size: e.size,
            episode: 1,
            season: e.season,
            subtitlePaths: e.subtitlePaths,
            danmakuPath: e.danmakuPath,
          );
        }
        return Show(
          id: g.id,
          title: g.season != null && g.season! > 1
              ? '${searchableTitle(g.title)} Season ${g.season}'
              : searchableTitle(g.title),
          folderPath: g.folder,
          season: g.season,
          episodes: g.episodes,
        );
      }).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  return shows;
}

class _Group {
  _Group({required this.id, required this.title, this.season, this.folder});
  final String id;
  final String title;
  final int? season;
  final String? folder;
  final List<EpisodeFile> episodes = [];
}
