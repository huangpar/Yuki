import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// A row of thumbnails with an "Add photo" tile. Each pick is uploaded straight
/// away and reported back as a storage path, so the screen only ever holds a
/// list of paths to save with whatever it belongs to.
class PhotoPicker extends StatefulWidget {
  /// 'profile', 'job', or 'review' — decides where the photo is stored.
  final String kind;

  /// Paths already attached, in the order they should show.
  final List<String> paths;

  /// Preview URLs for photos saved earlier, keyed by path. Photos picked in
  /// this session preview from memory instead, so they need no entry here.
  final Map<String, String> urls;

  final int max;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  const PhotoPicker({
    super.key,
    required this.kind,
    required this.paths,
    required this.onChanged,
    this.urls = const {},
    this.max = 4,
    this.enabled = true,
  });

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  static const _tile = 88.0;

  final _picker = ImagePicker();

  /// Bytes for photos picked in this session, keyed by the path they went to.
  final Map<String, Uint8List> _justPicked = {};
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    setState(() => _error = null);

    final XFile? file;
    try {
      // Resized on the way in: a phone photo is far larger than a thumbnail needs.
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      setState(() => _error = 'Could not open your photos.');
      return;
    }
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final path = await SupabaseService.instance.uploadPhoto(
        kind: widget.kind,
        bytes: bytes,
        contentType: _contentType(file.name, file.mimeType),
      );
      if (!mounted) return;
      setState(() => _justPicked[path] = bytes);
      widget.onChanged([...widget.paths, path]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That photo could not be uploaded.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(int index) {
    final path = widget.paths[index];
    _justPicked.remove(path);
    widget.onChanged([...widget.paths]..removeAt(index));
  }

  static String _contentType(String name, String? mimeType) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType == 'image/jpg' ? 'image/jpeg' : mimeType;
    }
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Widget _preview(int index) {
    final path = widget.paths[index];
    final bytes = _justPicked[path];
    if (bytes != null) {
      return Image.memory(bytes, width: _tile, height: _tile, fit: BoxFit.cover);
    }
    final url = widget.urls[path];
    if (url != null) {
      return Image.network(url, width: _tile, height: _tile, fit: BoxFit.cover);
    }
    return const Icon(Icons.image_outlined, color: AppColors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.paths.length >= widget.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _tile,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.paths.length + (full ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, index) {
              if (index == widget.paths.length) {
                return _AddTile(size: _tile, busy: _busy, onTap: widget.enabled ? _add : null);
              }
              return _Thumbnail(
                size: _tile,
                onRemove: widget.enabled && !_busy ? () => _remove(index) : null,
                child: _preview(index),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _error ?? 'Up to ${widget.max} photos',
          style: AppTypography.caption.copyWith(
            color: _error == null ? AppColors.textSecondary : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final bool busy;
  final VoidCallback? onTap;

  const _AddTile({required this.size, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.border),
          color: AppColors.background,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 22),
                    SizedBox(height: 2),
                    Text('Add', style: AppTypography.caption),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final double size;
  final Widget child;
  final VoidCallback? onRemove;

  const _Thumbnail({required this.size, required this.child, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            child: Container(color: AppColors.background, child: Center(child: child)),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
