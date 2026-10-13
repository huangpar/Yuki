import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thumbnails of photos someone attached, tappable for a full-size look.
/// Renders nothing when there are no photos, so callers can drop it in anywhere.
class PhotoStrip extends StatelessWidget {
  final List<String> urls;
  final double size;

  const PhotoStrip({super.key, required this.urls, this.size = 72});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) => InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          onTap: () => _open(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            child: Image.network(
              urls[index],
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: AppColors.background,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      builder: (_) => _PhotoViewer(urls: urls, startAt: index),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int startAt;

  const _PhotoViewer({required this.urls, required this.startAt});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.startAt);
  late int _current = widget.startAt;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Stack(
        children: [
          SizedBox(
            height: 480,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (page) => setState(() => _current = page),
              itemBuilder: (_, index) => InteractiveViewer(
                child: Center(child: Image.network(widget.urls[index], fit: BoxFit.contain)),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: AppSpacing.md,
              left: 0,
              right: 0,
              child: Text(
                '${_current + 1} of ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
