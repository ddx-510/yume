import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'cover_image.dart';
import 'glass.dart';

/// Poster with title + subtitle underneath; lifts slightly on hover.
class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress,
    this.badge,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 0..1 progress line along the bottom of the poster.
  final double? progress;

  /// Small glass label in the top-left corner, e.g. "In library".
  final String? badge;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: _hover ? 1.03 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hover ? const Color(0x55FFFFFF) : Palette.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(
                          url: widget.coverUrl,
                          fallbackTitle: widget.title,
                        ),
                        if (widget.badge != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  color: const Color(0x66000000),
                                  child: Text(
                                    widget.badge!,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.progress != null && widget.progress! > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ThinProgress(widget.progress!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Palette.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid delegate shared by every poster grid.
const posterGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 180,
  childAspectRatio: 0.58,
  crossAxisSpacing: 20,
  mainAxisSpacing: 24,
);

/// Blurred cover art filling the screen behind a detail page.
class CoverBackdrop extends StatelessWidget {
  const CoverBackdrop({super.key, required this.coverUrl});
  final String? coverUrl;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Opacity(
        opacity: 0.45,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: CoverImage(url: coverUrl, fallbackTitle: ''),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x66050507), Color(0xF2050507)],
            stops: [0, 0.6],
          ),
        ),
      ),
    ],
  );
}
