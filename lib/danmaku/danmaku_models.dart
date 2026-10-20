import 'dart:ui';

import 'package:xml/xml.dart';

enum DanmakuMode { scroll, top, bottom }

class DanmakuComment {
  const DanmakuComment({
    required this.time,
    required this.text,
    this.mode = DanmakuMode.scroll,
    this.color = const Color(0xFFFFFFFF),
  });

  /// Seconds from the start of the episode.
  final double time;
  final String text;
  final DanmakuMode mode;
  final Color color;

  static DanmakuMode modeFromInt(int m) => switch (m) {
    4 => DanmakuMode.bottom,
    5 => DanmakuMode.top,
    _ => DanmakuMode.scroll,
  };

  static Color colorFromInt(int c) => Color(0xFF000000 | (c & 0xFFFFFF));
}

/// Parses DanDanPlay `/api/v2/comment` JSON: `p = "time,mode,color,uid"`.
List<DanmakuComment> parseDandanComments(Map<String, dynamic> json) {
  final list = (json['comments'] as List? ?? const []).cast<Map>();
  final out = <DanmakuComment>[];
  for (final c in list) {
    final parts = (c['p'] as String? ?? '').split(',');
    if (parts.length < 3) continue;
    final time = double.tryParse(parts[0]);
    if (time == null) continue;
    out.add(
      DanmakuComment(
        time: time,
        mode: DanmakuComment.modeFromInt(int.tryParse(parts[1]) ?? 1),
        color: DanmakuComment.colorFromInt(int.tryParse(parts[2]) ?? 0xFFFFFF),
        text: (c['m'] as String? ?? '').trim(),
      ),
    );
  }
  return out..sort((a, b) => a.time.compareTo(b.time));
}

/// Parses Bilibili-style XML: `<d p="time,mode,size,color,...">text</d>`.
List<DanmakuComment> parseBilibiliXml(String xml) {
  final doc = XmlDocument.parse(xml);
  final out = <DanmakuComment>[];
  for (final d in doc.findAllElements('d')) {
    final parts = (d.getAttribute('p') ?? '').split(',');
    if (parts.length < 4) continue;
    final time = double.tryParse(parts[0]);
    if (time == null) continue;
    out.add(
      DanmakuComment(
        time: time,
        mode: DanmakuComment.modeFromInt(int.tryParse(parts[1]) ?? 1),
        color: DanmakuComment.colorFromInt(int.tryParse(parts[3]) ?? 0xFFFFFF),
        text: d.innerText.trim(),
      ),
    );
  }
  return out..sort((a, b) => a.time.compareTo(b.time));
}
