import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'error_banner.dart';
import 'rating_stars.dart';

/// Asks for stars and an optional note, then saves the review.
/// Pops with the rating that was saved, or null if the person backed out.
class ReviewDialog extends StatefulWidget {
  final String bookingId;

  /// Who is being rated, e.g. "Maya" or "your customer".
  final String subjectName;

  /// A rating already left for this booking, which this review replaces.
  final int? existingRating;

  const ReviewDialog({
    super.key,
    required this.bookingId,
    required this.subjectName,
    this.existingRating,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _comment = TextEditingController();
  late int _rating = widget.existingRating ?? 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to leave a rating.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.submitReview(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(_rating);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save your review. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('How did it go with ${widget.subjectName}?', style: AppTypography.h3),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: StarPicker(
                rating: _rating,
                onChanged: _saving ? null : (value) => setState(() {
                  _rating = value;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _comment,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
                hintText: 'What should other people know?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ErrorBanner(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                )
              : Text(widget.existingRating == null ? 'Post review' : 'Update review'),
        ),
      ],
    );
  }
}

/// Opens [ReviewDialog] and returns the rating that was saved, if any.
Future<int?> askForReview(
  BuildContext context, {
  required String bookingId,
  required String subjectName,
  int? existingRating,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReviewDialog(
      bookingId: bookingId,
      subjectName: subjectName,
      existingRating: existingRating,
    ),
  );
}
