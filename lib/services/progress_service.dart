import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'json_store.dart';

/// Remembers playback position per episode file.
class ProgressService extends ChangeNotifier {
  ProgressService(this._store);

  final JsonStore _store;
  final Map<String, PlaybackProgress> _byPath = {};

  PlaybackProgress? of(String path) => _byPath[path];

  Future<void> load() async {
    final data = await _store.read();
    if (data is Map) {
      data.forEach(
        (k, v) => _byPath[k as String] = PlaybackProgress.fromJson(
          (v as Map).cast<String, dynamic>(),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> save(String path, Duration position, Duration duration) async {
    if (duration <= Duration.zero) return;
    _byPath[path] = PlaybackProgress(
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _store.write(_byPath.map((k, v) => MapEntry(k, v.toJson())));
  }

  Future<void> clear(String path) async {
    _byPath.remove(path);
    notifyListeners();
    await _store.write(_byPath.map((k, v) => MapEntry(k, v.toJson())));
  }

  /// Where to resume, or null to start from the beginning.
  Duration? resumePoint(String path) {
    final p = _byPath[path];
    if (p == null || p.watched || p.positionMs < 10000) return null;
    return Duration(milliseconds: p.positionMs - 3000);
  }

  /// Most recently played episode of a show, for "Continue watching".
  (EpisodeFile, PlaybackProgress)? lastPlayed(Show show) {
    (EpisodeFile, PlaybackProgress)? best;
    for (final e in show.episodes) {
      final p = _byPath[e.path];
      if (p != null &&
          (best == null || p.updatedAt.isAfter(best.$2.updatedAt))) {
        best = (e, p);
      }
    }
    return best;
  }
}
