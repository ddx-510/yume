import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Frosted-glass panel: backdrop blur + translucent fill + hairline border.
/// Use [blur] = false for many small tiles (blur is costly; the tint alone
/// still reads as glass over the dark canvas).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.blur = true,
    this.strong = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool blur;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: Palette.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: strong
              ? const [Color(0x24FFFFFF), Color(0x0FFFFFFF)]
              : const [Color(0x14FFFFFF), Color(0x08FFFFFF)],
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (!blur) return ClipRRect(borderRadius: shape, child: body);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: body,
      ),
    );
  }
}

/// App canvas: black with a few faint, heavily blurred colour glows so the
/// glass panels have something to frost.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget glow(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
      ),
    );
    return ColoredBox(
      color: Palette.background,
      child: Stack(
        children: [
          Positioned(
            top: -220,
            left: -160,
            child: glow(const Color(0x335B3FD9), 640),
          ),
          Positioned(
            bottom: -260,
            right: -200,
            child: glow(const Color(0x262D7FD9), 720),
          ),
          Positioned(
            top: 180,
            right: 120,
            child: glow(const Color(0x14D93F8C), 420),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "2023", "28 eps".
class GlassChip extends StatelessWidget {
  const GlassChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Palette.glass,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Palette.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: Palette.textDim),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Palette.textDim),
        ),
      ],
    ),
  );
}

/// Large page title used at the top of each tab.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing = const []});
  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 24, 16),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        ...trailing,
      ],
    ),
  );
}

/// Pill-shaped toggle used for simple filters.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: selected ? Colors.white : Palette.glass,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Colors.white : Palette.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.black : Palette.textDim,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Thin progress bar for episodes / continue watching.
class ThinProgress extends StatelessWidget {
  const ThinProgress(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 3,
      color: Colors.white,
      backgroundColor: Palette.glassStrong,
    ),
  );
}
