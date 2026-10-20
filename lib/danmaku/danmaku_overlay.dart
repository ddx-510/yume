import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'danmaku_models.dart';

/// Display options for the overlay.
class DanmakuStyle {
  const DanmakuStyle({
    this.fontSize = 22,
    this.opacity = 0.85,
    this.area = 0.6,
    this.duration = 9,
  });

  final double fontSize;
  final double opacity;

  /// Fraction of the height usable by scrolling comments.
  final double area;

  /// Seconds a scrolling comment takes to cross the screen.
  final double duration;
}

/// Holds the comment list and a playback clock. The player pushes position
/// updates; the overlay extrapolates between them for smooth motion.
class DanmakuController extends ChangeNotifier {
  List<DanmakuComment> _comments = const [];
  List<DanmakuComment> get comments => _comments;

  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool v) {
    _enabled = v;
    notifyListeners();
  }

  String? sourceLabel;
  DanmakuStyle style = const DanmakuStyle();

  double _anchorTime = 0;
  bool _playing = false;
  double _rate = 1;
  final _clock = Stopwatch()..start();
  int _generation = 0;

  /// Increments whenever comments change or a seek happens.
  int get generation => _generation;

  void setComments(List<DanmakuComment> c, {String? label}) {
    _comments = c;
    sourceLabel = label;
    _generation++;
    notifyListeners();
  }

  void updateClock(
    Duration position, {
    required bool playing,
    double rate = 1,
  }) {
    final t = position.inMicroseconds / 1e6;
    if ((t - now).abs() > 1.5) _generation++; // treat as seek
    _anchorTime = t;
    _playing = playing;
    _rate = rate;
    _clock.reset();
  }

  bool get playing => _playing;

  double get now => _playing
      ? _anchorTime + _clock.elapsedMicroseconds / 1e6 * _rate
      : _anchorTime;
}

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({super.key, required this.controller});
  final DanmakuController controller;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  final _engine = _DanmakuEngine();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _repaint.value++)..start();
    widget.controller.addListener(_onController);
  }

  void _onController() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (!c.enabled || c.comments.isEmpty) return const SizedBox.expand();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DanmakuPainter(_engine, c, _repaint),
        ),
      ),
    );
  }
}

class _Active {
  _Active(this.comment, this.fill, this.stroke, this.lane, this.speed);
  final DanmakuComment comment;
  final TextPainter fill;
  final TextPainter stroke;
  final int lane;

  /// Pixels per second (scroll mode only).
  final double speed;
  double get width => fill.width;
}

/// Lazily allocates comments to lanes as playback time advances. Rebuilt
/// from scratch on seeks, size or style changes.
class _DanmakuEngine {
  static const _fixedDuration = 4.0;
  static const _gap = 24.0;

  final List<_Active> _active = [];
  int _cursor = 0;
  double _lastTime = 0;
  int _generation = -1;
  Size _size = Size.zero;
  DanmakuStyle? _style;

  double _laneHeight(DanmakuStyle s) => s.fontSize * 1.35;

  void _reset(List<DanmakuComment> comments, double t, DanmakuStyle s) {
    _active.clear();
    // Start from comments that would still be on screen at time t.
    _cursor = _lowerBound(comments, t - s.duration);
    _lastTime = t;
  }

  int _lowerBound(List<DanmakuComment> list, double t) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].time < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void advance(DanmakuController c, Size size) {
    final t = c.now;
    final s = c.style;
    if (c.generation != _generation ||
        size != _size ||
        !identical(s, _style) ||
        t < _lastTime) {
      _generation = c.generation;
      _size = size;
      _style = s;
      _reset(c.comments, t, s);
    }
    _lastTime = t;

    // Drop expired comments.
    _active.removeWhere((a) {
      final age = t - a.comment.time;
      if (a.comment.mode == DanmakuMode.scroll) {
        return age * a.speed > size.width + a.width;
      }
      return age > _fixedDuration;
    });

    final laneH = _laneHeight(s);
    final scrollLanes = (size.height * s.area / laneH).floor().clamp(1, 40);
    final fixedLanes = (size.height * 0.5 / laneH).floor().clamp(1, 20);
    final list = c.comments;

    // Bound per-frame work after a big jump.
    var budget = 200;
    while (_cursor < list.length && list[_cursor].time <= t && budget-- > 0) {
      final cm = list[_cursor++];
      if (t - cm.time >
          (cm.mode == DanmakuMode.scroll ? s.duration : _fixedDuration)) {
        continue;
      }
      final fill = _painter(cm, s, stroke: false);
      final width = fill.width;
      final speed = (size.width + width) / s.duration;
      final lane = cm.mode == DanmakuMode.scroll
          ? _scrollLane(cm, width, speed, scrollLanes, size.width)
          : _fixedLane(cm.mode, fixedLanes);
      if (lane == null) continue; // screen is full: drop it, like Bilibili does
      _active.add(
        _Active(cm, fill, _painter(cm, s, stroke: true), lane, speed),
      );
    }
  }

  int? _scrollLane(
    DanmakuComment cm,
    double width,
    double speed,
    int lanes,
    double screenW,
  ) {
    final lastInLane = <int, _Active>{};
    for (final a in _active) {
      if (a.comment.mode != DanmakuMode.scroll) continue;
      final prev = lastInLane[a.lane];
      if (prev == null || a.comment.time > prev.comment.time) {
        lastInLane[a.lane] = a;
      }
    }
    for (var lane = 0; lane < lanes; lane++) {
      final p = lastInLane[lane];
      if (p == null) return lane;
      final elapsed = cm.time - p.comment.time;
      // Previous tail fully on screen with a gap...
      final entered = elapsed * p.speed >= p.width + _gap;
      // ...and the new one won't catch up before the previous leaves.
      final prevLeavesAt = p.comment.time + (screenW + p.width) / p.speed;
      final newReachesLeftAt = cm.time + screenW / speed;
      if (entered && newReachesLeftAt >= prevLeavesAt) return lane;
    }
    return null;
  }

  int? _fixedLane(DanmakuMode mode, int lanes) {
    final used = {
      for (final a in _active)
        if (a.comment.mode == mode) a.lane,
    };
    for (var lane = 0; lane < lanes; lane++) {
      if (!used.contains(lane)) return lane;
    }
    return null;
  }

  TextPainter _painter(
    DanmakuComment cm,
    DanmakuStyle s, {
    required bool stroke,
  }) {
    final style = TextStyle(
      fontSize: s.fontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      foreground: stroke
          ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = const Color(0xCC000000))
          : (Paint()..color = cm.color),
    );
    return TextPainter(
      text: TextSpan(text: cm.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  void paint(Canvas canvas, Size size, DanmakuController c) {
    final t = c.now;
    final s = c.style;
    final laneH = _laneHeight(s);
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, s.opacity.clamp(0.1, 1.0)),
    );
    for (final a in _active) {
      final age = t - a.comment.time;
      final Offset o;
      switch (a.comment.mode) {
        case DanmakuMode.scroll:
          o = Offset(size.width - age * a.speed, a.lane * laneH + 4);
        case DanmakuMode.top:
          o = Offset((size.width - a.width) / 2, a.lane * laneH + 4);
        case DanmakuMode.bottom:
          o = Offset(
            (size.width - a.width) / 2,
            size.height - (a.lane + 1) * laneH - 48,
          );
      }
      a.stroke.paint(canvas, o);
      a.fill.paint(canvas, o);
    }
    canvas.restore();
  }
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter(this.engine, this.controller, Listenable repaint)
    : super(repaint: repaint);
  final _DanmakuEngine engine;
  final DanmakuController controller;

  @override
  void paint(Canvas canvas, Size size) {
    engine.advance(controller, size);
    engine.paint(canvas, size, controller);
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter old) => true;
}
