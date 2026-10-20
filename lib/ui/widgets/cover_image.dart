import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_services.dart';

/// Cover art loaded through the on-disk [CoverCache], with a title fallback.
class CoverImage extends StatefulWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.fallbackTitle,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final String fallbackTitle;
  final BoxFit fit;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  Future<File?>? _file;
  String? _loadedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  void _load() {
    if (widget.url == _loadedUrl && _file != null) return;
    _loadedUrl = widget.url;
    _file = widget.url == null
        ? null
        : AppServices.of(context).covers.get(widget.url!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        widget.fallbackTitle,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    if (_file == null) return placeholder;
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        final f = snap.data;
        if (f == null) return placeholder;
        return Image.file(
          f,
          fit: widget.fit,
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}
